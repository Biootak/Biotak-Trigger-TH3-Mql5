//+------------------------------------------------------------------+
//| CanvasEngine.mqh - Immediate-Mode Canvas Render Engine          |
//|                                                                  |
//| NEW ARCHITECTURE (v3.11): zones/lines/midpoints stop being a     |
//| retained graph of hundreds of terminal objects and become pixel  |
//| operations in ONE full-chart bitmap (OBJ_BITMAP_LABEL resource). |
//|                                                                  |
//| ROOT-CAUSE FIX (why the old path was slow):                      |
//|   Old path: every zone = 1 OBJ_RECTANGLE + up to 3 border        |
//|   segments, every line = 1 OBJ_HLINE (+ optional label). Each    |
//|   object needs ObjectCreate + several ObjectSet* calls, and      |
//|   every one of those is an IPC round-trip into the terminal.     |
//|   At 144 levels x 2 directions a redraw reaches ~500+ objects    |
//|   and THOUSANDS of IPC calls - that is the lag you see when      |
//|   switching modes or timeframes.                                 |
//|   New path: geometry (pure math, zero platform calls) is built   |
//|   once per (mode|TF|base-price) signature and cached; the view   |
//|   is rasterized into a local pixel buffer at ~us per primitive   |
//|   and blitted with ONE ResourceCreate + ChartRedraw per frame.   |
//|   Mode change / TF switch / scroll / zoom / price-drag all       |
//|   become in-memory re-rasterizes - sub-millisecond.              |
//|                                                                  |
//| LAYERING (what stays as real objects):                           |
//|   - Canvas: zones, level lines, trigger lines, midpoints         |
//|   - Objects: custom-price line, ATR/TH/mode/lock/factor labels,  |
//|     High/Low lines (DrawMainLevels), TH3 tool drawings           |
//+------------------------------------------------------------------+
#ifndef CANVAS_ENGINE_MQH
#define CANVAS_ENGINE_MQH
#property strict

//+------------------------------------------------------------------+
//| CBiotakCanvas - minimal bitmap-label canvas (no stdlib dep)     |
//|                                                                  |
//| Pixels are uint ARGB (0xAARRGGBB). The bitmap is screen-anchored |
//| at the top-left of the chart window and re-blitted via           |
//| ResourceCreate on every Update(). Fully transparent pixels let   |
//| the chart (candles, grid) show through.                          |
//+------------------------------------------------------------------+
class CBiotakCanvas
{
private:
    string   m_objName;
    string   m_resName;
    int      m_width;
    int      m_height;
    uint     m_pixels[];
    bool     m_valid;
    bool     m_anchored;      // OBJ_BITMAP (chart-anchored) vs OBJ_BITMAP_LABEL
    datetime m_anchorT;       // anchor time/price for the anchored mode
    double   m_anchorP;
public:
    CBiotakCanvas() : m_objName(""), m_resName(""), m_width(0), m_height(0),
                      m_valid(false), m_anchored(false), m_anchorT(0), m_anchorP(0) {}

    bool Create(const string objName, const int w, const int h);
    bool CreateAnchored(const string objName, const datetime t0, const double p0,
                        const int w, const int h);
    bool SetAnchor(const datetime t0, const double p0);
    void Destroy();
    void Update();
    void Clear(const uint clrARGB);
    void ShiftRows(const int dy);
    void FillRect(const int x1, const int y1, const int x2, const int y2, const uint clrARGB);
    void HLineStyled(const int x1, const int x2, const int y, const int pxWidth, const uint clrARGB, const int style);
    void VLine(const int x, const int y1, const int y2, const uint clrARGB);

    bool Valid() const { return m_valid && m_width > 0 && m_height > 0; }
    int  Width()  const { return m_width; }
    int  Height() const { return m_height; }
    bool Anchored() const { return m_anchored; }
    datetime AnchorT() const { return m_anchorT; }
    double   AnchorP() const { return m_anchorP; }
};

//+------------------------------------------------------------------+
//| Create (or resize) the canvas object and its bitmap resource.    |
//+------------------------------------------------------------------+
bool CBiotakCanvas::Create(const string objName, const int w, const int h)
{
    if(w <= 0 || h <= 0) return false;
    if(m_valid && m_objName == objName && m_width == w && m_height == h) return true;

    Destroy();

    m_objName = objName;
    m_resName = "::" + objName;
    m_width   = w;
    m_height  = h;

    if(ArrayResize(m_pixels, w * h) != w * h) return false;
    Clear(0x00000000);

    if(!ObjectCreate(0, m_objName, OBJ_BITMAP_LABEL, 0, 0, 0))
    {
        ResetLastError();
        return false;
    }
    ObjectSetInteger(0, m_objName, OBJPROP_XDISTANCE, 0);
    ObjectSetInteger(0, m_objName, OBJPROP_YDISTANCE, 0);
    ObjectSetInteger(0, m_objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    // Non-interactive overlay: never blocks clicks, never selectable.
    ObjectSetInteger(0, m_objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, m_objName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, m_objName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, m_objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, m_objName, OBJPROP_ZORDER, 0);
    ObjectSetInteger(0, m_objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    if(!ObjectSetString(0, m_objName, OBJPROP_BMPFILE, m_resName))
        ResetLastError();

    // ARGB_RAW keeps the alpha byte: 0x00000000 pixels stay fully
    // transparent so the chart (candles/grid) shows through.
    if(!ResourceCreate(m_resName, m_pixels, (uint)m_width, (uint)m_height,
                       0, 0, 0, COLOR_FORMAT_ARGB_RAW))
    {
        ResetLastError();
        return false;
    }

    m_valid = true;
    return true;
}

//+------------------------------------------------------------------+
//| Create a chart-ANCHORED canvas (OBJ_BITMAP): the bitmap is bound  |
//| to a chart point (time, price), so the terminal moves it natively |
//| with the chart on scroll - exactly how MT4 objects behave.        |
//|                                                                  |
//| The buffer is oversized (see CanvasEnsureBuffer) and only needs   |
//| re-anchoring + re-rasterizing when the anchor drifts near the     |
//| buffer edge or the zoom changes.                                 |
//+------------------------------------------------------------------+
bool CBiotakCanvas::CreateAnchored(const string objName, const datetime t0, const double p0,
                                   const int w, const int h)
{
    if(w <= 0 || h <= 0) return false;
    // Reuse the existing buffer if it is already the right size/type
    // (the anchor itself is preserved - drift is handled natively).
    if(m_valid && m_objName == objName && m_anchored && m_width == w && m_height == h)
        return true;

    Destroy();

    m_objName = objName;
    m_resName = "::" + objName;
    m_width   = w;
    m_height  = h;
    m_anchored = true;
    m_anchorT  = t0;
    m_anchorP  = p0;

    if(ArrayResize(m_pixels, w * h) != w * h) return false;
    Clear(0x00000000);

    if(!ObjectCreate(0, m_objName, OBJ_BITMAP, 0, t0, p0))
    {
        ResetLastError();
        return false;
    }
    // Non-interactive overlay: never blocks clicks, never selectable.
    ObjectSetInteger(0, m_objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, m_objName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, m_objName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, m_objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    if(!ObjectSetString(0, m_objName, OBJPROP_BMPFILE, m_resName))
        ResetLastError();

    // ARGB_RAW keeps the alpha byte: 0x00000000 pixels stay fully
    // transparent so the chart (candles/grid) shows through.
    if(!ResourceCreate(m_resName, m_pixels, (uint)m_width, (uint)m_height,
                       0, 0, 0, COLOR_FORMAT_ARGB_RAW))
    {
        ResetLastError();
        return false;
    }

    m_valid = true;
    return true;
}

//+------------------------------------------------------------------+
//| Re-anchor the OBJ_BITMAP canvas to a new chart point (1 IPC).    |
//+------------------------------------------------------------------+
bool CBiotakCanvas::SetAnchor(const datetime t0, const double p0)
{
    if(!m_valid || !m_anchored) return false;
    m_anchorT = t0;
    m_anchorP = p0;
    return ObjectMove(0, m_objName, 0, t0, p0);
}

//+------------------------------------------------------------------+
//| Delete the chart object and drop the resource.                   |
//+------------------------------------------------------------------+
void CBiotakCanvas::Destroy()
{
    if(m_valid || StringLen(m_objName) > 0)
        ObjectDelete(0, m_objName);   // safe no-op when the object is gone
    m_valid = false;
    m_objName = "";
    m_resName = "";
    m_width = 0;
    m_height = 0;
    m_anchored = false;
    m_anchorT = 0;
    m_anchorP = 0;
}

//+------------------------------------------------------------------+
//| Blit the pixel buffer to the chart (the ONLY IPC per frame).     |
//+------------------------------------------------------------------+
void CBiotakCanvas::Update()
{
    if(!Valid()) return;
    if(!ResourceCreate(m_resName, m_pixels, (uint)m_width, (uint)m_height,
                       0, 0, 0, COLOR_FORMAT_ARGB_RAW))
        ResetLastError();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Shift the whole buffer vertically by dy pixels (dy>0 = content   |
//| moves down). The newly exposed band is cleared to transparent.   |
//|                                                                  |
//| This is the vertical-scroll fast path: instead of re-rasterizing  |
//| every primitive, the existing pixels (already correct at the old |
//| scale) are translated and only the exposed band is redrawn.      |
//+------------------------------------------------------------------+
void CBiotakCanvas::ShiftRows(const int dy)
{
    if(!Valid() || dy == 0) return;
    const int w = m_width;
    const int h = m_height;

    if(dy > 0)
    {
        // Content moves DOWN: new[y] = old[y - dy]. Copy bottom-up so
        // source rows are not overwritten before they are read.
        for(int y = h - 1; y >= dy; y--)
        {
            int src = (y - dy) * w;
            int dst = y * w;
            for(int x = 0; x < w; x++)
                m_pixels[dst + x] = m_pixels[src + x];
        }
        // Exposed top band
        for(int y = 0; y < dy; y++)
        {
            int dst = y * w;
            for(int x = 0; x < w; x++)
                m_pixels[dst + x] = 0x00000000;
        }
    }
    else
    {
        // Content moves UP by d: new[y] = old[y + d]. Copy top-down
        // (source rows are below the destination rows).
        int d = -dy;
        for(int y = 0; y < h - d; y++)
        {
            int src = (y + d) * w;
            int dst = y * w;
            for(int x = 0; x < w; x++)
                m_pixels[dst + x] = m_pixels[src + x];
        }
        // Exposed bottom band
        for(int y = h - d; y < h; y++)
        {
            int dst = y * w;
            for(int x = 0; x < w; x++)
                m_pixels[dst + x] = 0x00000000;
        }
    }
}

//+------------------------------------------------------------------+
//| Fill the whole buffer with one ARGB color.                       |
//+------------------------------------------------------------------+
void CBiotakCanvas::Clear(const uint clrARGB)
{
    int total = ArraySize(m_pixels);
    for(int i = 0; i < total; i++)
        m_pixels[i] = clrARGB;
}

//+------------------------------------------------------------------+
//| Fill an axis-aligned rectangle (clipped to the buffer).          |
//+------------------------------------------------------------------+
void CBiotakCanvas::FillRect(const int x1, const int y1, const int x2, const int y2, const uint clrARGB)
{
    if(!Valid()) return;
    int cx1 = (x1 < 0) ? 0 : x1;
    int cy1 = (y1 < 0) ? 0 : y1;
    int cx2 = (x2 >= m_width)  ? m_width - 1  : x2;
    int cy2 = (y2 >= m_height) ? m_height - 1 : y2;
    if(cx1 > cx2 || cy1 > cy2) return;

    for(int y = cy1; y <= cy2; y++)
    {
        int row = y * m_width;
        for(int x = cx1; x <= cx2; x++)
            m_pixels[row + x] = clrARGB;
    }
}

//+------------------------------------------------------------------+
//| Horizontal line with MQL5 line-style dash pattern and width.     |
//+------------------------------------------------------------------+
int CanvasPatternLen(const int style)
{
    switch(style)
    {
        case STYLE_DASH:       return 2;
        case STYLE_DOT:        return 2;
        case STYLE_DASHDOT:    return 4;
        case STYLE_DASHDOTDOT: return 6;
        default:               return 0;   // solid
    }
}

int CanvasPatternValue(const int style, const int idx)
{
    static const int PAT_DASH[]       = {5, 3};
    static const int PAT_DOT[]        = {1, 2};
    static const int PAT_DASHDOT[]    = {5, 2, 1, 2};
    static const int PAT_DASHDOTDOT[] = {5, 2, 1, 2, 1, 2};
    switch(style)
    {
        case STYLE_DASH:       return (idx >= 0 && idx < 2) ? PAT_DASH[idx]       : 1;
        case STYLE_DOT:        return (idx >= 0 && idx < 2) ? PAT_DOT[idx]        : 1;
        case STYLE_DASHDOT:    return (idx >= 0 && idx < 4) ? PAT_DASHDOT[idx]    : 1;
        case STYLE_DASHDOTDOT: return (idx >= 0 && idx < 6) ? PAT_DASHDOTDOT[idx] : 1;
        default:               return 1;
    }
}

void CBiotakCanvas::HLineStyled(const int x1, const int x2, const int y, const int pxWidth, const uint clrARGB, const int style)
{
    if(!Valid()) return;

    int wpx = pxWidth < 1 ? 1 : (pxWidth > 5 ? 5 : pxWidth);
    int yStart = y - wpx / 2;
    int plen = CanvasPatternLen(style);

    for(int yy = yStart; yy < yStart + wpx; yy++)
    {
        if(yy < 0 || yy >= m_height) continue;
        int row = yy * m_width;
        int s = (x1 < 0) ? 0 : x1;
        int e = (x2 >= m_width) ? m_width - 1 : x2;
        if(s > e) continue;

        if(plen <= 0)
        {
            for(int x = s; x <= e; x++)
                m_pixels[row + x] = clrARGB;
            continue;
        }

        int pi = 0;
        int rem = CanvasPatternValue(style, 0);
        bool on = true;
        for(int x = s; x <= e; x++)
        {
            if(on) m_pixels[row + x] = clrARGB;
            rem--;
            if(rem <= 0)
            {
                pi = (pi + 1) % plen;
                on = !on;
                rem = CanvasPatternValue(style, pi);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vertical 1px line (clipped).                                     |
//+------------------------------------------------------------------+
void CBiotakCanvas::VLine(const int x, const int y1, const int y2, const uint clrARGB)
{
    if(!Valid()) return;
    if(x < 0 || x >= m_width) return;
    int a = (y1 < 0) ? 0 : y1;
    int b = (y2 >= m_height) ? m_height - 1 : y2;
    if(a > b) return;
    for(int y = a; y <= b; y++)
        m_pixels[y * m_width + x] = clrARGB;
}

//+------------------------------------------------------------------+
//| Color helpers                                                    |
//+------------------------------------------------------------------+
uint CanvasARGB(const uchar alpha, const color clr)
{
    uint c = (uint)clr & 0xFFFFFF;
    return ((uint)alpha << 24) | c;
}

// Blend a zone color at the given transparency (0..100) over the
// chart background color -> opaque ARGB (approximates OBJ_RECTANGLE
// semi-transparent fill; over candles the tint is flat by design).
uint CanvasBlendOverBg(const color fg, const int transp, const color bg)
{
    int alpha = 100 - transp;                  // 0..100 (100 = opaque)
    if(alpha <= 0)   return CanvasARGB(0, bg);
    if(alpha >= 100) return CanvasARGB(255, fg);

    int a = (alpha * 255) / 100;
    int fr = (int)((fg >> 16) & 0xFF);
    int fg2 = (int)((fg >> 8) & 0xFF);
    int fb = (int)(fg & 0xFF);
    int br = (int)((bg >> 16) & 0xFF);
    int bg2 = (int)((bg >> 8) & 0xFF);
    int bb = (int)(bg & 0xFF);
    int r = (fr * a + br * (255 - a)) / 255;
    int g = (fg2 * a + bg2 * (255 - a)) / 255;
    int b = (fb * a + bb * (255 - a)) / 255;
    return 0xFF000000 | ((uint)r << 16) | ((uint)g << 8) | (uint)b;
}

// Double-composite the zone color over an already-blended pixel, so
// the box outline reads slightly stronger than the fill (mimics the
// OBJ_RECTANGLE border drawn over its own fill).
uint CanvasOverBlend(const uint baseARGB, const color fg, const int transp)
{
    int alpha = 100 - transp;
    if(alpha <= 0)   return baseARGB;
    if(alpha >= 100) return CanvasARGB(255, fg);

    int a = (alpha * 255) / 100;
    int fr = (int)((fg >> 16) & 0xFF);
    int fg2 = (int)((fg >> 8) & 0xFF);
    int fb = (int)(fg & 0xFF);
    int br = (int)((baseARGB >> 16) & 0xFF);
    int bg2 = (int)((baseARGB >> 8) & 0xFF);
    int bb = (int)(baseARGB & 0xFF);
    int r = (fr * a + br * (255 - a)) / 255;
    int g = (fg2 * a + bg2 * (255 - a)) / 255;
    int b = (fb * a + bb * (255 - a)) / 255;
    return 0xFF000000 | ((uint)r << 16) | ((uint)g << 8) | (uint)b;
}

//+------------------------------------------------------------------+
//| Engine state                                                     |
//|                                                                  |
//| The geometry model (stages 1-4 of LevelPipeline: Calculate,      |
//| Classify, BuildZonesAndLines) is cached per signature so mode    |
//| toggles and timeframe switches never recompute or re-IPC.        |
//+------------------------------------------------------------------+
#define CANVAS_MODEL_CACHE_SIZE 6

struct SCanvasModelEntry
{
    string sig;
    bool   valid;
    SModeConfig config;
    int    zoneCount;
    int    lineCount;
    int    maxStep;
    SZoneDefinition zones[];
    STriggerLine lines[];
};

static CBiotakCanvas g_canvas;
static string  g_canvasObjName = "";
static bool    g_canvasEngineEnabled = false;
static bool    g_canvasAnchored = false;   // true = OBJ_BITMAP (MT4-native scroll)
static SCanvasModelEntry g_canvasModels[CANVAS_MODEL_CACHE_SIZE];
static int     g_canvasModelCount = 0;
static int     g_canvasModelNext = 0;
static int     g_canvasCurrentModel = -1;

// Rasterize skip-key: when neither the model, the viewport, nor the
// visibility flags changed, the frame is a no-op (O(1) per tick).
static string g_canvasLastSig = "";
static int    g_canvasLastYTop = -1;
static int    g_canvasLastYBottom = -1;
static bool   g_canvasLastShowLines = false;
static bool   g_canvasLastTriggers = false;
static bool   g_canvasLastHidden = false;
static bool   g_canvasHasLast = false;
static double g_canvasLastMax = 0;   // CHART_PRICE_MAX/MIN at last blit
static double g_canvasLastMin = 0;   // (used by the scroll shift fast path)

//+------------------------------------------------------------------+
//| Engine lifecycle                                                 |
//+------------------------------------------------------------------+
bool CanvasEngineActive()
{
    return g_canvasEngineEnabled;
}

void CanvasEngineSetActive(const bool enabled)
{
    g_canvasEngineEnabled = enabled;
    if(!enabled)
        CanvasEngineDeinit();
}

void CanvasEngineSetAnchored(const bool anchored)
{
    g_canvasAnchored = anchored;
}

void CanvasEngineDeinit()
{
    g_canvas.Destroy();
    g_canvasCurrentModel = -1;
    g_canvasHasLast = false;
    for(int i = 0; i < CANVAS_MODEL_CACHE_SIZE; i++)
    {
        g_canvasModels[i].valid = false;
        g_canvasModels[i].sig = "";
        ArrayFree(g_canvasModels[i].zones);
        ArrayFree(g_canvasModels[i].lines);
    }
    g_canvasModelCount = 0;
    g_canvasModelNext = 0;
}

// Drop cached geometry only (canvas object stays alive). Called on
// timeframe change so stale per-TF models do not linger.
void CanvasEngineResetModels()
{
    g_canvasCurrentModel = -1;
    g_canvasHasLast = false;
    for(int i = 0; i < CANVAS_MODEL_CACHE_SIZE; i++)
    {
        g_canvasModels[i].valid = false;
        g_canvasModels[i].sig = "";
        ArrayFree(g_canvasModels[i].zones);
        ArrayFree(g_canvasModels[i].lines);
    }
    g_canvasModelCount = 0;
    g_canvasModelNext = 0;
}

//+------------------------------------------------------------------+
//| Model cache                                                      |
//+------------------------------------------------------------------+
string CanvasBuildSignature(const SModeConfig &config, const double centerPrice,
                            const double &stepSizes[], const int stepSizeCount,
                            const ENUM_LEVEL_STEP_MODE stepMode,
                            const ENUM_CLASSIFY_MODE classifyMode,
                            const bool lsFirst, const int maxLevelsAbove, const int maxLevelsBelow)
{
    string sig = config.objectPrefix + "|" + DoubleToString(centerPrice, 12) + "|"
               + IntegerToString((int)stepMode) + "|" + IntegerToString((int)classifyMode) + "|"
               + (lsFirst ? "1" : "0") + "|" + IntegerToString(maxLevelsAbove) + "|"
               + IntegerToString(maxLevelsBelow) + "|"
               + (config.boundByHistorical ? "1" : "0") + "|"
               + DoubleToString(config.maxPrice, 10) + "|" + DoubleToString(config.minPrice, 10) + "|"
               + (IsTriggerLevelsEnabled() ? "1" : "0") + "|"
               + IntegerToString(GetValidatedBaseMultiplier()) + "|"
               + DoubleToString(config.zoneHeightPercent, 8) + "|"
               + IntegerToString(config.zoneTransparency) + "|"
               + IntegerToString((int)config.zoneStyle) + "|"
               + IntegerToString((int)config.zoneDefaultColor) + "|"
               + IntegerToString((int)config.fallbackColor) + "|"
               + IntegerToString((int)config.fallbackColor2) + "|"
               + (config.useObjPropBack ? "1" : "0") + "|"
               + IntegerToString(config.zOrder) + "|"
               + (config.hideLineWhenTriggerOnly ? "1" : "0") + "|";
    for(int i = 0; i < stepSizeCount; i++)
        sig += DoubleToString(stepSizes[i], 12) + ";";
    return sig;
}

int CanvasFindModel(const string sig)
{
    for(int i = 0; i < g_canvasModelCount; i++)
        if(g_canvasModels[i].valid && g_canvasModels[i].sig == sig)
            return i;
    return -1;
}

// Run pipeline stages 1-4 (pure math, no platform calls) and cache.
bool CanvasBuildModel(const string sig, const SModeConfig &config, const double centerPrice,
                      const double &stepSizes[], const int stepSizeCount,
                      const ENUM_LEVEL_STEP_MODE stepMode,
                      const ENUM_CLASSIFY_MODE classifyMode, const bool lsFirst,
                      const int maxLevelsAbove, const int maxLevelsBelow)
{
    int maxStep = 0;
    SCalculatedLevel rawLevels[];
    int rawCount = CalculateLevels(centerPrice, stepSizes, stepSizeCount, stepMode,
                                   maxLevelsAbove, maxLevelsBelow,
                                   config.boundByHistorical, config.maxPrice, config.minPrice,
                                   rawLevels, maxStep);
    if(rawCount <= 0) return false;

    SLevelClassified classified[];
    bool triggerEnabled = IsTriggerLevelsEnabled();
    int baseMultiplier = GetValidatedBaseMultiplier();
    int classifiedCount = 0;
    if(classifyMode == CLASSIFY_ALTERNATING)
        classifiedCount = ClassifyLevelsAlternating(rawLevels, rawCount, config,
                                                    triggerEnabled, baseMultiplier, lsFirst,
                                                    classified);
    else
        classifiedCount = ClassifyLevels(rawLevels, rawCount, config,
                                         triggerEnabled, baseMultiplier, classified);

    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);
    SZoneDefinition zones[];
    STriggerLine lines[];
    int zoneCount = 0, lineCount = 0;
    BuildZonesAndLines(classified, classifiedCount, config, vpTop, vpBottom,
                       zones, zoneCount, lines, lineCount);

    int slot = g_canvasModelNext;
    g_canvasModelNext = (g_canvasModelNext + 1) % CANVAS_MODEL_CACHE_SIZE;
    if(g_canvasModelCount < CANVAS_MODEL_CACHE_SIZE)
        g_canvasModelCount++;

    // MQL5 forbids local references to array elements; write through the
    // slot index directly.
    ArrayResize(g_canvasModels[slot].zones, zoneCount);
    for(int i = 0; i < zoneCount; i++) g_canvasModels[slot].zones[i] = zones[i];
    ArrayResize(g_canvasModels[slot].lines, lineCount);
    for(int i = 0; i < lineCount; i++) g_canvasModels[slot].lines[i] = lines[i];
    g_canvasModels[slot].sig = sig;
    g_canvasModels[slot].valid = true;
    g_canvasModels[slot].config = config;
    g_canvasModels[slot].zoneCount = zoneCount;
    g_canvasModels[slot].lineCount = lineCount;
    g_canvasModels[slot].maxStep = maxStep;
    return true;
}

//+------------------------------------------------------------------+
//| Overscan margins for the anchored mode. The canvas is larger     |
//| than the visible plot area so the terminal can move it natively   |
//| for a long scroll distance before a re-anchor is needed.         |
//+------------------------------------------------------------------+
int CanvasOverscanY(const int plotH)
{
    return MathMin(MathMax(plotH / 3, 150), 400);
}

int CanvasOverscanX(const int w)
{
    return MathMin(MathMax(w / 4, 120), 300);
}

// Row offset added by the anchored mode (0 for the screen-anchored
// mode): canvas row r corresponds to screen row (r - offset).
int CanvasCurrentOffset(const int yTop, const int yBottom)
{
    if(!g_canvasAnchored) return 0;
    return CanvasOverscanY(yBottom - yTop);
}

//+------------------------------------------------------------------+
//| Viewport mapping                                                 |
//+------------------------------------------------------------------+
bool CanvasGetPlotBounds(int &yTop, int &yBottom)
{
    // Fallback bounds are the WINDOW height (the anchored buffer is
    // taller than the screen, so the canvas height is not the screen
    // height - only the plot area mapping matters here).
    int winH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    yTop = 0;
    yBottom = winH - 1;
    if(yBottom < 1) return false;

    double pMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double pMin = ChartGetDouble(0, CHART_PRICE_MIN);
    if(pMax <= pMin) return false;

    // Y coordinates depend only on the price scale, so any in-range time
    // works; TimeCurrent() is always available.
    datetime t = TimeCurrent();
    if(t <= 0) return false;

    int x = 0, y1 = 0, y2 = 0;
    if(!ChartTimePriceToXY(0, 0, t, pMax, x, y1)) return false;
    if(!ChartTimePriceToXY(0, 0, t, pMin, x, y2)) return false;
    if(y2 <= y1) return false;

    yTop = y1;
    yBottom = y2;
    return true;
}

int CanvasPriceToY(const double price, const int yTop, const int yBottom)
{
    double pMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double pMin = ChartGetDouble(0, CHART_PRICE_MIN);
    if(pMax <= pMin) return yTop;
    if(price >= pMax) return yTop;
    if(price <= pMin) return yBottom;
    double t = (pMax - price) / (pMax - pMin);
    return yTop + (int)MathRound(t * (double)(yBottom - yTop));
}

//+------------------------------------------------------------------+
//| Rasterize the cached model into the canvas buffer, clipping all  |
//| drawing to the horizontal band [bandTop..bandBottom].            |
//|                                                                  |
//| The band variant is used by the scroll fast path: after the      |
//| buffer is shifted by the price delta, only the newly exposed     |
//| band holds stale pixels and needs redrawing. A full rasterize    |
//| simply passes the whole canvas as the band.                      |
//+------------------------------------------------------------------+
void CanvasRasterizeEx(const SCanvasModelEntry &model,
                       const int yTop, const int yBottom,
                       const int bandTop, const int bandBottom,
                       const int offset)
{
    if(!g_canvas.Valid()) return;
    if(!model.valid) return;
    if(bandTop > bandBottom) return;

    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);

    color bg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool hidden = IsIndicatorHidden();
    bool showLines = GetCachedLinesVisible() && !hidden;
    int borderStyle = (int)inpMidZoneBorderStyle;
    int borderWidth = (int)inpMidZoneBorderWidth;
    if(borderWidth < 1) borderWidth = 1;
    int zoneStyle = (int)model.config.zoneStyle;
    bool zonesOn = model.config.zonesEnabled && !hidden && zoneStyle != ZONE_STYLE_HIDDEN;

    int w = g_canvas.Width();

    // Zones (background layer)
    if(zonesOn)
    {
        for(int i = 0; i < model.zoneCount; i++)
        {
            if(model.zones[i].isTrigger && !triggerEnabled) continue;
            if(model.zones[i].renderTop <= model.zones[i].renderBottom) continue;
            if(!(model.zones[i].renderTop >= vpBottom &&
                 model.zones[i].renderBottom <= vpTop)) continue;

            int yt = CanvasPriceToY(model.zones[i].renderTop, yTop, yBottom) + offset;
            int yb = CanvasPriceToY(model.zones[i].renderBottom, yTop, yBottom) + offset;
            if(yt > yb) continue;

            if(zoneStyle == ZONE_STYLE_BOX_FILLED)
            {
                uint fill = CanvasBlendOverBg(model.zones[i].zoneColor, model.zones[i].transparency, bg);
                uint bd = CanvasOverBlend(fill, model.zones[i].zoneColor, model.zones[i].transparency);
                int r1 = (yt < bandTop) ? bandTop : yt;
                int r2 = ((yb - 1) > bandBottom) ? bandBottom : (yb - 1);
                if(r1 <= r2)
                    g_canvas.FillRect(0, r1, w - 1, r2, fill);
                if(yt >= bandTop && yt <= bandBottom)
                    g_canvas.HLineStyled(0, w - 1, yt, borderWidth, bd, borderStyle);
                if((yb - 1) >= bandTop && (yb - 1) <= bandBottom)
                    g_canvas.HLineStyled(0, w - 1, yb - 1, borderWidth, bd, borderStyle);
            }
            else
            {
                // BOX_EMPTY: hollow outline (top/bottom/left/right)
                uint bd = CanvasBlendOverBg(model.zones[i].zoneColor, model.zones[i].transparency, bg);
                if(yt >= bandTop && yt <= bandBottom)
                    g_canvas.HLineStyled(0, w - 1, yt, borderWidth, bd, borderStyle);
                if((yb - 1) >= bandTop && (yb - 1) <= bandBottom)
                    g_canvas.HLineStyled(0, w - 1, yb - 1, borderWidth, bd, borderStyle);
                if(yt <= bandBottom && yb >= bandTop)
                {
                    int va = (yt < bandTop) ? bandTop : yt;
                    int vb = ((yb - 1) > bandBottom) ? bandBottom : (yb - 1);
                    g_canvas.VLine(0,     va, vb, bd);
                    g_canvas.VLine(w - 1, va, vb, bd);
                }
            }
        }
    }

    // Lines (foreground layer)
    if(showLines)
    {
        for(int i = 0; i < model.lineCount; i++)
        {
            if(model.lines[i].price <= 0) continue;
            if(model.config.hideLineWhenTriggerOnly && !model.lines[i].isMidpoint && triggerEnabled) continue;
            if(!(model.lines[i].price >= vpBottom && model.lines[i].price <= vpTop)) continue;

            int y = CanvasPriceToY(model.lines[i].price, yTop, yBottom) + offset;
            if(y < bandTop || y > bandBottom) continue;

            int lw = model.lines[i].lineWidth < 1 ? 1 : model.lines[i].lineWidth;
            g_canvas.HLineStyled(0, w - 1, y, lw,
                                 CanvasARGB(255, model.lines[i].clr),
                                 (int)model.lines[i].lineStyle);
        }
    }
}

//+------------------------------------------------------------------+
//| Full-buffer rasterize (clears first, draws everything).          |
//+------------------------------------------------------------------+
void CanvasRasterize(const SCanvasModelEntry &model)
{
    if(!g_canvas.Valid()) return;
    if(!model.valid) return;

    int yTop = 0, yBottom = 0;
    if(!CanvasGetPlotBounds(yTop, yBottom))
    {
        yTop = 0;
        yBottom = g_canvas.Height() - 1;
    }
    int offset = CanvasCurrentOffset(yTop, yBottom);

    g_canvas.Clear(0x00000000);
    CanvasRasterizeEx(model, yTop, yBottom, 0, g_canvas.Height() - 1, offset);
}

//+------------------------------------------------------------------+
//| Remember the frame state used by the skip-key and the scroll     |
//| shift fast path.                                                 |
//+------------------------------------------------------------------+
void CanvasStoreLastState(const string sig, const int yTop, const int yBottom)
{
    g_canvasLastSig = sig;
    g_canvasLastYTop = yTop;
    g_canvasLastYBottom = yBottom;
    g_canvasLastShowLines = GetCachedLinesVisible() && !IsIndicatorHidden();
    g_canvasLastTriggers = IsTriggerLevelsEnabled();
    g_canvasLastHidden = IsIndicatorHidden();
    g_canvasLastMax = ChartGetDouble(0, CHART_PRICE_MAX);
    g_canvasLastMin = ChartGetDouble(0, CHART_PRICE_MIN);
    g_canvasHasLast = true;
}

//+------------------------------------------------------------------+
//| Ensure the canvas buffer exists at the right size/type.          |
//|                                                                  |
//| Screen mode:  buffer = chart window (w x winH).                  |
//| Anchored mode: buffer = window + overscan margins; the bitmap is |
//| bound to the chart point at the screen top-left, so the terminal |
//| moves it natively with the chart (MT4 behavior).                 |
//+------------------------------------------------------------------+
bool CanvasEnsureBuffer(const int w, const int winH, const int yTop, const int yBottom,
                        bool &recreated)
{
    recreated = false;
    if(w <= 0 || winH <= 0) return false;

    if(g_canvasObjName == "")
        g_canvasObjName = inpObjectPrefix + "_Canvas_" + (string)ChartID();

    if(!g_canvasAnchored)
    {
        bool wasValid = g_canvas.Valid();
        int oldW = g_canvas.Width();
        int oldH = g_canvas.Height();
        if(!g_canvas.Create(g_canvasObjName, w, winH)) return false;
        if(!wasValid || oldW != w || oldH != winH)
        {
            recreated = true;
            g_canvasHasLast = false;
        }
        return true;
    }

    // Anchored: oversize the buffer so re-anchors are rare.
    int plotH = yBottom - yTop;
    if(plotH < 10) plotH = winH - 10;
    int OV  = CanvasOverscanY(plotH);
    int OVX = CanvasOverscanX(w);
    int cw = w + 2 * OVX;
    int ch = plotH + 2 * OV;

    datetime t0;
    double p0;
    int cx = 0, cy = 0, csub = 0;
    if(!ChartXYToTimePrice(0, cx, cy, csub, t0, p0))
    {
        t0 = TimeCurrent();
        p0 = ChartGetDouble(0, CHART_PRICE_MAX);
    }

    bool wasValid = g_canvas.Valid();
    if(!g_canvas.CreateAnchored(g_canvasObjName, t0, p0, cw, ch))
    {
        // OBJ_BITMAP unavailable/failed on this terminal -> fall back to the
        // screen-anchored buffer so the levels still render (scroll sync is
        // then handled by the per-event shift path instead of natively).
        g_canvasAnchored = false;
        if(!g_canvas.Create(g_canvasObjName, w, winH)) return false;
        recreated = true;
        g_canvasHasLast = false;
        return true;
    }
    if(!wasValid || g_canvas.Width() != cw || g_canvas.Height() != ch)
    {
        recreated = true;
        g_canvasHasLast = false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Re-anchor the anchored canvas to the chart point currently at the |
//| screen top-left (1 ObjectMove IPC).                              |
//+------------------------------------------------------------------+
bool CanvasAnchorNow()
{
    if(!g_canvasAnchored) return false;
    datetime t0;
    double p0;
    int cx = 0, cy = 0, csub = 0;
    if(!ChartXYToTimePrice(0, cx, cy, csub, t0, p0)) return false;
    return g_canvas.SetAnchor(t0, p0);
}

//+------------------------------------------------------------------+
//| Full draw: ensure canvas size, (re)build model if needed,        |
//| rasterize + blit. No-op when nothing changed.                    |
//+------------------------------------------------------------------+
bool CanvasEngineDraw(const SModeConfig &config, const double centerPrice,
                      const double &stepSizes[], const int stepSizeCount,
                      const ENUM_LEVEL_STEP_MODE stepMode,
                      const ENUM_CLASSIFY_MODE classifyMode, const bool lsFirst,
                      const int maxLevelsAbove, const int maxLevelsBelow)
{
    if(!g_canvasEngineEnabled) return false;

    int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    if(w <= 0 || h <= 0) return false;

    string sig = CanvasBuildSignature(config, centerPrice, stepSizes, stepSizeCount,
                                      stepMode, classifyMode, lsFirst,
                                      maxLevelsAbove, maxLevelsBelow);
    int modelIdx = CanvasFindModel(sig);
    if(modelIdx < 0)
    {
        if(!CanvasBuildModel(sig, config, centerPrice, stepSizes, stepSizeCount,
                             stepMode, classifyMode, lsFirst,
                             maxLevelsAbove, maxLevelsBelow))
            return false;
        modelIdx = CanvasFindModel(sig);
        if(modelIdx < 0) return false;
    }
    g_canvasCurrentModel = modelIdx;

    int yTop = 0, yBottom = h - 1;
    CanvasGetPlotBounds(yTop, yBottom);

    bool recreated = false;
    if(!CanvasEnsureBuffer(w, h, yTop, yBottom, recreated)) return false;
    // A fresh anchored buffer is created already aligned; no extra move.
    // (CreateAnchored passed the current screen top-left point.)

    bool showLines = GetCachedLinesVisible() && !IsIndicatorHidden();
    bool trig = IsTriggerLevelsEnabled();
    bool hid = IsIndicatorHidden();

    if(g_canvasHasLast && !recreated && g_canvasLastSig == sig &&
       g_canvasLastYTop == yTop && g_canvasLastYBottom == yBottom &&
       g_canvasLastShowLines == showLines && g_canvasLastTriggers == trig &&
       g_canvasLastHidden == hid)
        return true;

    CanvasRasterize(g_canvasModels[modelIdx]);
    g_canvas.Update();
    CanvasStoreLastState(sig, yTop, yBottom);
    return true;
}

//+------------------------------------------------------------------+
//| Viewport-only refresh (scroll/zoom/resize).                      |
//|                                                                  |
//| Vertical scroll with constant zoom uses the SHIFT fast path: the |
//| existing pixels are translated by the price delta and only the   |
//| exposed band is redrawn (no per-primitive re-rasterize). Zoom /  |
//| resize / first draw fall back to a full rasterize. Horizontal    |
//| scroll changes nothing (all primitives are full-width) -> no-op. |
//|                                                                  |
//| @param force  when true (hotkey toggles like L/F) the shift      |
//|               fast path is skipped so visibility changes baked   |
//|               into the canvas are re-applied.                    |
//|                                                                  |
//| @return true if handled, false if no model is cached yet         |
//|         (caller falls back to a full redraw).                    |
//+------------------------------------------------------------------+
bool CanvasEngineRefreshViewport(const bool force = false)
{
    if(!g_canvasEngineEnabled) return false;
    if(g_canvasCurrentModel < 0 || !g_canvasModels[g_canvasCurrentModel].valid) return false;

    int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    if(w <= 0 || h <= 0) return false;

    string sig = g_canvasModels[g_canvasCurrentModel].sig;
    int yTop = 0, yBottom = h - 1;
    CanvasGetPlotBounds(yTop, yBottom);

    bool recreated = false;
    if(!CanvasEnsureBuffer(w, h, yTop, yBottom, recreated)) return false;

    if(g_canvasAnchored)
    {
        // ---- ANCHORED MODE (OBJ_BITMAP, MT4-native scroll) ----
        // The terminal already moved the canvas with the chart. We only
        // act when: the buffer was recreated, the zoom changed, or the
        // anchor drifted near the buffer edge (re-anchor + rasterize).
        // Otherwise the canvas is already glued to the prices - nothing
        // to do, which is exactly how MT4 objects behave.
        double pMax = ChartGetDouble(0, CHART_PRICE_MAX);
        double pMin = ChartGetDouble(0, CHART_PRICE_MIN);
        double range = pMax - pMin;
        double lastRange = g_canvasLastMax - g_canvasLastMin;
        double eps = MathMax(GetCachedPoint() * 2.0, range * 0.001);
        bool zoomChanged = !(range > 0 && lastRange > 0 && MathAbs(range - lastRange) <= eps);

        int ax = 0, ay = 0;
        bool haveDrift = g_canvas.Anchored() &&
                         ChartTimePriceToXY(0, 0, g_canvas.AnchorT(), g_canvas.AnchorP(), ax, ay);
        int OV  = CanvasOverscanY(yBottom - yTop);
        int OVX = CanvasOverscanX(w);

        if(force || recreated || zoomChanged || !haveDrift ||
           ax > OVX - 30 || ax < -(OVX - 30) || ay > OV - 30 || ay < -(OV - 30))
        {
            if(g_canvasAnchored) CanvasAnchorNow();
            CanvasRasterize(g_canvasModels[g_canvasCurrentModel]);
            g_canvas.Update();
            CanvasStoreLastState(sig, yTop, yBottom);
        }
        // else: native movement - nothing to re-blit
        return true;
    }

    // ---- SCREEN-ANCHORED MODE (OBJ_BITMAP_LABEL) ----
    if(!force && g_canvasHasLast)
    {
        // Fast path: pure vertical scroll keeps the visible price RANGE
        // constant (only its offset changes). Detect it and shift pixels.
        double pMax = ChartGetDouble(0, CHART_PRICE_MAX);
        double pMin = ChartGetDouble(0, CHART_PRICE_MIN);
        double range = pMax - pMin;
        double lastRange = g_canvasLastMax - g_canvasLastMin;
        double eps = MathMax(GetCachedPoint() * 2.0, range * 0.001);
        if(range > 0 && lastRange > 0 && MathAbs(range - lastRange) <= eps)
        {
            double pxPerPrice = (double)(yBottom - yTop) / range;
            double p0 = (pMax + pMin) * 0.5;
            double lastP0 = (g_canvasLastMax + g_canvasLastMin) * 0.5;
            int dy = (int)MathRound((p0 - lastP0) * pxPerPrice);

            if(dy == 0)
            {
                // Horizontal scroll or pure repaint: content is already
                // correct (full-width primitives) - just refresh bounds.
                CanvasStoreLastState(sig, yTop, yBottom);
                return true;
            }
            if(MathAbs(dy) < h)
            {
                g_canvas.ShiftRows(dy);
                int bandTop, bandBottom;
                if(dy > 0) { bandTop = 0;    bandBottom = dy - 1; }
                else       { bandTop = h + dy; bandBottom = h - 1; }
                if(bandTop <= bandBottom)
                    CanvasRasterizeEx(g_canvasModels[g_canvasCurrentModel],
                                      yTop, yBottom, bandTop, bandBottom, 0);
                g_canvas.Update();
                CanvasStoreLastState(sig, yTop, yBottom);
                return true;
            }
            // |dy| >= h: page-level jump -> fall through to full rasterize
        }
    }

    // Full re-rasterize (zoom change, resize, first draw, big jump,
    // or forced hotkey refresh)
    CanvasRasterize(g_canvasModels[g_canvasCurrentModel]);
    g_canvas.Update();
    CanvasStoreLastState(sig, yTop, yBottom);
    return true;
}

//+------------------------------------------------------------------+
//| Clear the canvas (levels hidden/disabled).                       |
//+------------------------------------------------------------------+
void CanvasEngineClear()
{
    if(!g_canvas.Valid()) return;
    g_canvas.Clear(0x00000000);
    g_canvas.Update();
    g_canvasHasLast = false;
}

#endif // CANVAS_ENGINE_MQH
