// ============================================================================
// OWNED MT5 module - forked from the MetaTrader 4 source on 2026-10-12.
//   MT4 source : Biotak/Biotak/DrawStrip.mqh
//
// MT4 remains the LOGIC reference and tools/parity/module-report.py flags
// any drift, but nothing regenerates this file: MT5-only changes live here
// directly, marked MT5-ONLY / P-MT5-* / P-PERF-*.
//
// MT5-only changes this file already carries:
//   * MQL5 ObjectCreate needs an explicit ENUM_OBJECT cast  (1 substitution)
//   * the diag channel prints nothing unless DSTRIP_DIAG is set  (1 substitution)
// ============================================================================
//+------------------------------------------------------------------+
//|                                                 DrawStrip.mqh     |
//|   P-DRAW-08 (2026-09-22) — THE FLOATING STRIP OF THE USER'S DRAWINGS.|
//|   P-DRAW-09 (2026-09-23) — THE MODERN FACE, THE GROUP, THREE CONTROLS.|
//|   P-DRAW-10 (2026-09-23) — THE TRADINGVIEW FACE: LIGHT ICON CELLS.    |
//|   P-DRAW-11 (2026-09-23) — DIRECT PICK, NO CYCLING (BASEKNOT PARITY+).|
//|   P-UI-113 (2026-09-23) — LEFT-HOLD OPENS (right-click era deleted).  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Biotak Project"
#property strict

#ifndef DRAW_STRIP_MQH
#define DRAW_STRIP_MQH

// DrawStrip_Head.mqh - DrawStrip split 2026-09-29: exact lines 15-677 of DrawStrip.mqh, byte-identical, zero renames.
#ifndef DRAW_STRIP_HEAD_MQH
#define DRAW_STRIP_HEAD_MQH

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-10 (2026-09-23) — THE ICON FACE. User order: «مثل استریپ تریدینگ ویو بشه»:
// a small floating bar of LIGHT ICON CELLS, the value in the tooltip. Two laws
// carry it, and the 08i pass that concluded "a bitmap label ships empty" had both
// wrong (the reasoning is in git history):
//   * the raster must be EMBEDDED — `OBJPROP_BMPFILE` with a "::Files\\Icons\\"
//     path resolves only for a file this module `#resource`d, and every raster is
//     listed in `tools/icon-manifest.txt`;
//   * the CELL must be the control — MT4 paints a label at the file's NATIVE size
//     from its own corner, so the art is centred by arithmetic and the CLICK
//     target stays the OBJ_BUTTON underneath (Z_PANEL_BASE/Z_PANEL_SKIN): the
//     icon is a face, the button is the control, a click on either name routes.
// A cell whose value is a WORD (ray mode, caption size, arrow code, template
// name, "All") keeps the word: an icon that lies is worse than a word that says
// it (P-DRAW-08d, still binding).
// ══════════════════════════════════════════════════════════════════════════

//--- P-DRAW-10: the embedded rasters. One line per icon family the strip can
//--- wear; R-ICON (panel-wiring-audit) fails the build if any of these is
//--- missing from `tools/icon-manifest.txt`, because a #resource outside the
//--- manifest embeds a ghost file nobody regenerates.
#resource "\\Files\\Icons\\bk_w1.bmp"
#resource "\\Files\\Icons\\bk_w2.bmp"
#resource "\\Files\\Icons\\bk_w3.bmp"
#resource "\\Files\\Icons\\bk_w4.bmp"
#resource "\\Files\\Icons\\bk_w5.bmp"
#resource "\\Files\\Icons\\bk_style0.bmp"
#resource "\\Files\\Icons\\bk_style1.bmp"
#resource "\\Files\\Icons\\bk_style2.bmp"
#resource "\\Files\\Icons\\bk_style3.bmp"
#resource "\\Files\\Icons\\bk_style4.bmp"
#resource "\\Files\\Icons\\bk_bucket.bmp"
#resource "\\Files\\Icons\\bk_lock_on.bmp"
#resource "\\Files\\Icons\\bk_lock_off.bmp"
//--- P-UI-131: the BACK seat's OFF twin. Declared beside its ON face so the strip's
//--- one control wears ONE shape in two inks (a #resource a painter names without a
//--- declaration is a SILENT no-op at paint time — tools/check-resources.js).
#resource "\\Files\\Icons\\bk_back_off.bmp"
#resource "\\Files\\Icons\\bk_del.bmp"
#resource "\\Files\\Icons\\gl_layers_m.bmp"
#resource "\\Files\\Icons\\gl_template_m.bmp"
//--- P-DRAW-13 (2026-09-23) — the V6 icon-only faces. State carriers vary per
//--- value (bk_ray0..3, like bk_w*/bk_style*); pure glyphs ride one raster and
//--- the gold face carries the state. gl_* reuses (pin/pin-gold, plus, check,
//--- textsize, layers) are owned by their own modules' #resource lines —
//--- R-ICON allows sharing: every raster below is #resource'd HERE, which is
//--- what the gate checks.
#resource "\\Files\\Icons\\bk_ray0.bmp"
#resource "\\Files\\Icons\\bk_ray1.bmp"
#resource "\\Files\\Icons\\bk_ray2.bmp"
#resource "\\Files\\Icons\\bk_ray3.bmp"
#resource "\\Files\\Icons\\bk_glyph.bmp"
#resource "\\Files\\Icons\\bk_levels.bmp"
#resource "\\Files\\Icons\\bk_gear.bmp"
#resource "\\Files\\Icons\\bk_grip.bmp"
#resource "\\Files\\Icons\\bk_copy.bmp"
#resource "\\Files\\Icons\\bk_undo.bmp"
#resource "\\Files\\Icons\\bk_fill_on.bmp"
#resource "\\Files\\Icons\\bk_half_off.bmp"
#resource "\\Files\\Icons\\bk_half_on.bmp"
// P-UI-139/140: the PATH's own 50 % face (two legs, a dot on each middle) — declared
// here beside the box's pair, because a raster a unit PAINTS must be `#resource`d in
// that same unit (a missing declaration is a silent runtime no-op).
#resource "\\Files\\Icons\\bk_mid_off.bmp"
#resource "\\Files\\Icons\\bk_mid_on.bmp"
//--- P-UI-140: `path_mid_dot.bmp` is declared BESIDE ITS PAINTER (PathTool.mqh), not
//--- here: a `#resource` is a COMPILE-time bind of the unit that PAINTS the raster
//--- (P-UI-131's two-tree law), and the path's marker is painted by the path — which
//--- is in BOTH builds, while this file is not. Declaring it here left Lite painting a
//--- raster it never declared.
#resource "\\Files\\Icons\\bk_ext_off.bmp"
#resource "\\Files\\Icons\\bk_ext_on.bmp"
#resource "\\Files\\Icons\\bk_back_on.bmp"
#resource "\\Files\\Icons\\bk_lock_on_g.bmp"
#resource "\\Files\\Icons\\ds_swatch24.bmp"
#resource "\\Files\\Icons\\gl_pin_m.bmp"
#resource "\\Files\\Icons\\gl_pin_gold.bmp"
#resource "\\Files\\Icons\\gl_plus_m.bmp"
#resource "\\Files\\Icons\\gl_check_m.bmp"
#resource "\\Files\\Icons\\gl_textsize_m.bmp"
//--- P-DRAW-29 (2026-09-24) — the plate wears the cards' own skin: the 9-slice
//--- `ds_*` set baked by tools/gen-th3-icons.js (R-ICON: manifest-listed, like
//--- every raster above). The mid-row centre is a plain DSTRIP_CLR_PANEL rect.
#resource "\\Files\\Icons\\ds_top_l.bmp"
#resource "\\Files\\Icons\\ds_top_m.bmp"
#resource "\\Files\\Icons\\ds_top_r.bmp"
#resource "\\Files\\Icons\\ds_mid_l.bmp"
#resource "\\Files\\Icons\\ds_mid_r.bmp"
#resource "\\Files\\Icons\\ds_bot_l.bmp"
#resource "\\Files\\Icons\\ds_bot_m.bmp"
#resource "\\Files\\Icons\\ds_bot_r.bmp"
//--- P-PAL-17 (2026-10-02) - THE COLOUR BOARD'S OWN NINE, `ds_pb_*`, baked at the modern corner so the box around the palette speaks the same recipe as the cells inside it. Declared beside the set it replaces for family 2 ONLY; the strip's and the settings panel's plate keep the shipped `ds_*` art, byte for byte. Level 0 only: the board has no transparency levels (P-DRAW-89).
#resource "\\Files\\Icons\\ds_pb_top_l.bmp"
#resource "\\Files\\Icons\\ds_pb_top_m.bmp"
#resource "\\Files\\Icons\\ds_pb_top_r.bmp"
#resource "\\Files\\Icons\\ds_pb_mid_l.bmp"
#resource "\\Files\\Icons\\ds_pb_mid_r.bmp"
#resource "\\Files\\Icons\\ds_pb_bot_l.bmp"
#resource "\\Files\\Icons\\ds_pb_bot_m.bmp"
#resource "\\Files\\Icons\\ds_pb_bot_r.bmp"
//--- P-DRAW-43 (2026-09-25) — THE PLATE'S TRANSPARENCY LEVELS, baked (MT4 has no
//--- runtime image API, so a % plate is a file set, not a slider): the same eight
//--- pieces at 30/60/90 %, the levels `DSTRIP_PLATE_T` behind the gear's own row.
#resource "\\Files\\Icons\\ds_top_l_t30.bmp"
#resource "\\Files\\Icons\\ds_top_m_t30.bmp"
#resource "\\Files\\Icons\\ds_top_r_t30.bmp"
#resource "\\Files\\Icons\\ds_mid_l_t30.bmp"
#resource "\\Files\\Icons\\ds_mid_r_t30.bmp"
#resource "\\Files\\Icons\\ds_bot_l_t30.bmp"
#resource "\\Files\\Icons\\ds_bot_m_t30.bmp"
#resource "\\Files\\Icons\\ds_bot_r_t30.bmp"
#resource "\\Files\\Icons\\ds_top_l_t60.bmp"
#resource "\\Files\\Icons\\ds_top_m_t60.bmp"
#resource "\\Files\\Icons\\ds_top_r_t60.bmp"
#resource "\\Files\\Icons\\ds_mid_l_t60.bmp"
#resource "\\Files\\Icons\\ds_mid_r_t60.bmp"
#resource "\\Files\\Icons\\ds_bot_l_t60.bmp"
#resource "\\Files\\Icons\\ds_bot_m_t60.bmp"
#resource "\\Files\\Icons\\ds_bot_r_t60.bmp"
#resource "\\Files\\Icons\\ds_top_l_t90.bmp"
#resource "\\Files\\Icons\\ds_top_m_t90.bmp"
#resource "\\Files\\Icons\\ds_top_r_t90.bmp"
#resource "\\Files\\Icons\\ds_mid_l_t90.bmp"
#resource "\\Files\\Icons\\ds_mid_r_t90.bmp"
#resource "\\Files\\Icons\\ds_bot_l_t90.bmp"
#resource "\\Files\\Icons\\ds_bot_m_t90.bmp"
#resource "\\Files\\Icons\\ds_bot_r_t90.bmp"
//--- P-DRAW-33 (2026-09-24) — THE COLOUR SURFACES WEAR THE CARDS' GLASS. User
//--- report: «مشکلاتش چیه چرا از رنگ ها شیشه استفاده نشده مثل بقیه». Every card
//--- control in this project is a flat button with a `pnl_glass*` frame over it
//--- (RICH-MT4: transparent middle, so the colour shows through, plus the baked
//--- top-light / bottom-shade), and the strip's colour cells were the ONE surface
//--- left flat. Baked at the two sizes the strip actually uses: 32 (quick row +
//--- colour popover cell) and 28 (the gear's swatch grid) — MT4 CROPS a bitmap
//--- label, never scales it.
//--- ICON-DIET 2026-09-27: pnl_glass32 and pnl_glass28 are gone. Every face the
//--- gear, the picker and the recent ring draw is ds_cell32 / ds_ring32 /
//--- ds_swatch24 (the kind-0 swatch branch — the last pnl_glass28 caller — was
//--- deleted with the icon diet). The two size-table entries below went with
//--- them, so no branch can name a file that no longer exists.
#resource "\\Files\\Icons\\ds_cell32.bmp"
#resource "\\Files\\Icons\\ds_ring32.bmp"
#resource "\\Files\\Icons\\dsg_btn_ghost.bmp"
//--- P-DRAW-74: there is NO filled-primary bake left in the panel — the foot's Close
//--- took it. The builder is `tools/gen-th3-icons.js` -> `ftBtnSkin('gold', true, 64)`;
//--- the declaration, the manifest line and the file went with the caller (I3/I6).
#resource "\\Files\\Icons\\pnl_topbar_gold.bmp"
#resource "\\Files\\Icons\\pnl_hair_gold.bmp"
//--- P-DRAW-73: the W twins of the head's own two pieces, declared HERE because this
//--- is the only module that draws them (a wide gear head). They lived in
//--- BiotakPanels.mqh, so a wide panel's head art hung on an unrelated include.
#resource "\\Files\\Icons\\pnl_topbarW_gold.bmp"
#resource "\\Files\\Icons\\pnl_hairW_gold.bmp"
#resource "\\Files\\Icons\\pnl_mark_gold.bmp"
#resource "\\Files\\Icons\\pnl_chip.bmp"
#resource "\\Files\\Icons\\pnl_chip_gold.bmp"
#resource "\\Files\\Icons\\pnl_rail_gold.bmp"
#resource "\\Files\\Icons\\pnl_sw_off.bmp"
#resource "\\Files\\Icons\\pnl_sw_on_gold.bmp"
#resource "\\Files\\Icons\\pnl_vchip_gold.bmp"
#resource "\\Files\\Icons\\pnl_xbtn.bmp"
#resource "\\Files\\Icons\\pnl_subdot_amber.bmp"
#resource "\\Files\\Icons\\pnl_subdot_jade.bmp"
#resource "\\Files\\Icons\\pnl_secdot_gold.bmp"
#resource "\\Files\\Icons\\pnl_cntchip.bmp"
//--- P-DRAW-81: THE PANEL'S OWN PLATE, DECLARED HERE. This is the defect behind
//--- «the panel has no skin at all»: the settings panel paints `pnl_card{n}` and
//--- `pnl_cardW*` (DrawStripGearPlate) and `pnl_btn_ghost` (its foot), but those
//--- `#resource` lines lived only in BiotakPanels.mqh — which is included AFTER
//--- this file (entry lines 99 and 118). On MT4 `#resource` binds per COMPILING
//--- UNIT, not per module: a `::Files\...` BMPFILE resolves ONLY for a raster the
//--- unit declared, so every one of those writes was a silent no-op — the plate
//--- painted nothing at all and the foot button had no skin. A green compile said
//--- nothing, because the name is a string.
//--- The ten narrow bakes the generator emits (`PNL_CARD_ROWS_MAX` 10, one per
//--- row count, 340 x (174+42n)), plus the three composed W pieces and the ghost
//--- button this module paints. Declared where they are DRAWN, like every other
//--- raster above.
#resource "\\Files\\Icons\\pnl_card1.bmp"
#resource "\\Files\\Icons\\pnl_card2.bmp"
#resource "\\Files\\Icons\\pnl_card3.bmp"
#resource "\\Files\\Icons\\pnl_card4.bmp"
#resource "\\Files\\Icons\\pnl_card5.bmp"
#resource "\\Files\\Icons\\pnl_card6.bmp"
#resource "\\Files\\Icons\\pnl_card7.bmp"
#resource "\\Files\\Icons\\pnl_card8.bmp"
#resource "\\Files\\Icons\\pnl_card9.bmp"
#resource "\\Files\\Icons\\pnl_card10.bmp"
#resource "\\Files\\Icons\\pnl_cardWtop.bmp"
#resource "\\Files\\Icons\\pnl_cardWmid.bmp"
#resource "\\Files\\Icons\\pnl_cardWbot.bmp"
#resource "\\Files\\Icons\\pnl_btn_ghost.bmp"
//--- P-DRAW-81: the foot's reset glyph, same defect — the painter names it and
//--- this unit never declared it, so the button drew its skin and no icon.
#resource "\\Files\\Icons\\gl_reset_m.bmp"
//--- P-DRAW-81: the quick row's own "..." cell, found by the same audit — named at
//--- DrawStripActRes (line 1140) and never declared, so that one cell was blank.
#resource "\\Files\\Icons\\bk_more.bmp"
#resource "\\Files\\Icons\\gl_box_i_gold.bmp"
#resource "\\Files\\Icons\\gl_line_i_gold.bmp"
#resource "\\Files\\Icons\\gl_type_i_gold.bmp"
#resource "\\Files\\Icons\\gl_target_i_gold.bmp"
#resource "\\Files\\Icons\\gl_sigma_i_gold.bmp"
#resource "\\Files\\Icons\\gl_x_gold.bmp"
#resource "\\Files\\Icons\\gl_check_gold.bmp"
#resource "\\Files\\Icons\\gl_nav_m.bmp"
#resource "\\Files\\Icons\\gl_droplet_m.bmp"

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-08 — ONE STRIP, EVERY DRAWING TOOL, ITS OWN CONTROLS. A hold on any
// drawing opens ITS OWN toolbar, not the box's. Deliberately the OPPOSITE shape
// from item 13's bitmap strip: it renders itself from the drawing's KIND (so it
// shows exactly the controls that kind has), owns its objects
// (create/refresh/destroy) with no framework state, and one owner serves seventeen
// kinds with no per-type code.
// P-DRAW-11 retired the cycler (a value cell OPENS its picker now; only toggles and
// actions fire at once) and P-DRAW-09/10/13 shaped the face: a header naming the
// drawing, wrapping rows, state-coloured faces, contrast-correct swatch ink, the
// controls MT4 buries (font, glyph, behind) and the group. Every write is guarded
// (P-PERF-02) and the forced repaint fires only when a pixel moved — created once
// per hold, destroyed on dismiss, nothing in the mouse stream.
// ══════════════════════════════════════════════════════════════════════════

// P-DRAW-08i: the paint loop walks DSTRIP_MAX_SLOTS, so a slot past the ceiling
// would be silently never drawn. P-DRAW-13: quick cells are capped at six
// (DSTRIP_QUICK_CAP); the twelve is headroom for the cap plus chrome.
// P-DRAW-09: a kind has at most ten cells (six of its own + Tpl/Save/✕/All).
#define DSTRIP_MAX_SLOTS 12
//--- P-DRAW-11 (2026-09-23) — DIRECT PICK, NO CYCLING. The cycler is retired: a tap
// on a VALUE cell OPENS that value's picker and the pick applies directly; toggles
// (fill/lock/behind) and the three actions (Save/All/Del) fire at once — one tap, one
// list, the current value highlighted, for all seventeen drawing kinds. The picker is
// INLINE (the strip's own second block — no popover, no palette window, no card-12
// jump), it carries the palette plus the recents, the template list lives in the
// strip, the group rides every pick, and the picker survives a re-anchor.
// THE AFFORDANCE WITHOUT A CHEVRON BITMAP: MT4 renders "▼" as "?" in Wine fonts, so
// the rim carries it — a value cell wears DSTRIP_CLR_PICK (ACCENT while its own
// picker is open) and an ON toggle wears the ACCENT face. Rim = has a list.
// P-DRAW-13 — V6, icon-only one row (grip | badge | <=6 value icons | more | gear |
// pin | trash) plus one docked popover and a gear panel. What MT4 cannot do is cut
// with a named ceiling, never silently dropped: no text-edit in the row (the gear
// panel's OBJ_EDITs own typing), no per-level on/off (levels edit MEMBERSHIP), no
// font-name cycle, and trash is not undoable. Created on demand, destroyed with the
// strip; nothing here runs in the mouse stream.
#define DSTRIP_PICK_NONE (-99)  // no popover open
#define DSTRIP_MORE      (-60)  // the more-popover (sections, not a slot)
#define DSTRIP_SLOT_MORE   (-6) // quick: the "..." popover
#define DSTRIP_SLOT_GEAR   (-7) // quick: the full-settings panel
#define DSTRIP_SLOT_PIN    (-8) // quick: pin toggle (stays while editing)
#define DSTRIP_SLOT_LEVELS (-9) // quick: the fibo level-membership editor
//--- P-DRAW-13: the V6 shell metrics. ONE 30px row, icon-only, 2px gaps — the
//--- preview's minimal-space rule. Nothing wraps any more: overflow value slots
//--- live in the more-popover, never on a second row.
#define DSTRIP_CELL      32    // the one row's height, and every icon cell's width
#define DSTRIP_SWATCH    24    // the colour cell's own swatch (the preview's .swcell: 24px, B-05's floor)
#define DSTRIP_GAP        4
#define DSTRIP_PAD        8    // plate padding
#define DSTRIP_PICK_MAX  72    // popover rows/cells: the picker grid's 64 + recents (P-DRAW-46)
#define DSTRIP_PICK_ROW   42   // ONE mid band per swatch row — this pitch IS the plate's
                               // 48 + 42k law (DSTRIP_SKIN_MID, DrawStripSkinKFor)
#define DSTRIP_PICK_CELL  32
#define DSTRIP_PICK_GAP    8
#define DSTRIP_GRID_MAX  72    // option cells in one gear grid block (the picker's 64 fits)
#define DSTRIP_GLIST_MAX 24    // list rows in one gear block — P-DRAW-117: the
                               // GROUP HEADERS ride the same array as the open
                               // group's rows, so a fibo's 14 levels + both
                               // management rows + five headers (21) must fit
//--- P-DRAW-116 (2026-10-01) — THE PANEL'S NUMBERS ARE THE CARDS' NUMBERS. These
//--- five were the panel's own literals, each equal to the card's own by hand:
//--- 312 / 16 / 56 / 42 / 48 = PNL_WEL / PNL_PAD_X / PNL_HEAD_H / PNL_ROW_H /
//--- PNL_FOOT_H. They are now ALIASES of it — same value today (so not one pixel of
//--- any surface moves), and no longer two tables that can part company the first time
//--- either side is retuned. The table lives in `CardMetrics.mqh`, which the entry
//--- includes ABOVE this file; that is the only reason a `PNL_*` name can be read here
//--- at all (DrawStrip is include 99, BiotakPanels 118).
//--- DEPENDENTS, named as the Touch rule asks: `DSTRIP_GEAR_W` 10 reads / 5 files ·
//--- `DSTRIP_GEAR_PAD` 17/5 · `DSTRIP_GEAR_HEAD_H` 11/6 · `DSTRIP_GEAR_ROW_H` 27/6 ·
//--- `DSTRIP_GEAR_FOOT_H` 4/3 · `DSTRIP_GEAR_LBL_PT` 4/3 · `DSTRIP_SKIN_M` 35/6 —
//--- every one of them keeps its name and its value; only the number's owner changed.
#define DSTRIP_GEAR_W   PNL_WEL
#define DSTRIP_GEAR_PAD  PNL_PAD_X
#define DSTRIP_GEAR_HEAD_H PNL_HEAD_H
#define DSTRIP_GEAR_ROW_H  PNL_ROW_H
#define DSTRIP_GEAR_TB_H   7   // the head's own top bar, at the head's top edge
#define DSTRIP_GEAR_HR_H   5   // ...and the hair that CLOSES it (P-DRAW-73)
#define DSTRIP_GEAR_FOOT_H PNL_FOOT_H   // P-DRAW-116: the card's own footer (was 42)
//--- P-DRAW-74 (2026-09-28): the foot carries COMMANDS. Its Close stood beside the
//--- header's own X and wore the panel's one FILLED block, so the loudest thing on a
//--- card whose job is to change a drawing was the way out of it (C-03).
//--- P-DRAW-78: TWO foot buttons, All and Copy. The third was `Del`, and the
//--- strip's own command group already carries a trash cell that asks first
//--- (DrawSelCount in its tooltip) — so the panel carried a second, unconfirmed
//--- way to destroy the drawing. One owner per action.
//--- P-DRAW-90 (2026-09-30) — AND THE THIRD IS `Reset`, not `Del`. The design
//--- (tools/mock-strip-refactor.html:573, footer) draws three commands:
//--- `Reset` at the content's left edge (the only one wearing a glyph, the cards'
//--- own reset ring) and `All`·`Copy` as a pair flush to its right — the mock's
//--- own `.sp` spacer between them. The code shipped TWO, and gave the RESET ring
//--- to `All` (DrawStrip_GearB.mqh:1019): a face that lied about its action.
//--- `Reset` returns THIS drawing to its kind's factory look (the kind's own
//--- built-in preset 0), which the panel had no way to reach at all.
#define DSTRIP_GEAR_FOOT_N 3
//--- P-DRAW-80: the foot button's width is the CARDS' own formula
//--- (`max(72, 32 + advance + 8)`, BiotakPanels PnlFootBtnW) — the flat 64 that
//--- stood here is retired, and with it every reader.
#define DSTRIP_GEAR_FOOT_BW 72   // the formula's floor; the measured width wins above it
#define DSTRIP_GEAR_FOOT_GAP 8
//--- P-DRAW-107 (2026-10-01): the ring's advance inside a foot button — 15px of art
//--- plus its gap, i.e. the cards' own `bx+12 -> bx+32` relation (`32 - 12`), kept
//--- as ONE number. The ring's seat (DrawStripFootGlyphX) and the word's
//--- (DrawStripFootLabelX) both read it, so the pair cannot drift apart on a plate
//--- whose width is measured (`DrawStripFootBw`) rather than fixed.
#define DSTRIP_GEAR_FOOT_GLYPH_ADV 20
#define DSTRIP_GEAR_GRID_GAP 8
#define DSTRIP_GEAR_SWATCH 28
#define DSTRIP_GEAR_CHIP   48   // 5 chips per row in 280px content (5*48 + 4*8 = 272 < 280)
#define DSTRIP_GEAR_CHIP_H 32
#define DSTRIP_GEAR_EDIT_H 22   // P-DRAW-66: the board's own field height (DSTRIP_POP_EDIT_H)
//--- P-DRAW-117 (2026-10-01) — THE PANEL IS AN ACCORDION, AND A GROUP IS A ROW.
//--- The horizontal tab row (DSTRIP_TAB_H/GAP/PAD/UL and the GTrack bed under it)
//--- is RETIRED: the groups are first-class 42px ROWS now, each standing on the
//--- card's own row grid with its icon, its name and the value it currently holds,
//--- and the open group's settings hang directly under its own header. The retired
//--- spellings are deleted by the panel's own purge, so a chart painted by the tab
//--- build cannot leave a `GT*`/`GTrack`/`GU` behind (Touch rule 2).
#define DSTRIP_SEC_CNT_W 24    // P-DRAW-71: a band's count pill (the cards' .cnt)
#define DSTRIP_SEC_CNT_H 16    // P-DRAW-73: the bake's own height (cntChipSkin 24x16)
//--- P-DRAW-123 (2026-10-01) — THE PANEL'S OWN DIAG SWITCH, and the reason it exists:
//--- a paint defect that only the TERMINAL can show had no machine-readable output, so
//--- every report ended as a screenshot read by eye. With this 1, a panel OPEN or a group
//--- switch prints one `[dsdiag] EXPECT` line per painted panel object (name, role, seat,
//--- layer, text) immediately followed by the `[drawstrip] TABCENSUS` reality walk of the
//--- SAME state, and `python tools/diag-diff.py <log>` names the objects that differ.
//--- commented out = silent (the call sites compile away). Never per paint: armed by
//--- `DrawStripGearDiagDump()` on a user action, the same bound the census always had.
#define DSTRIP_DIAG 1
//--- the group row (DSTRIP_GRK_GROUP) and its own two seats: the value DIGEST is
//--- right-aligned `DSTRIP_GEAR_DG_PAD` in from the cell, and the label is fitted
//--- against it with the row's own gap between.
#define DSTRIP_GRK_GROUP  9    // gear row kind 9 = a group header (opens/collapses)
#define DSTRIP_GEAR_DG_PAD 12  // the digest's own inset from the cell's right edge
//--- P-DRAW-118 (2026-10-01) — THE COLOR ROWS ARE THE CARDS' OWN QUICK ROW.
//--- User order: «این color fill از همین جا بشه رنگها شو تغییر داد ... کد رنگ
//--- چیکارش کنم ... پنل تنظیمات اصلی ... مثل همون بکنش ... یک جا یک پارچه باشه».
//--- The panel's two hex BOXES are gone: a colour is chosen by a SWATCH, the way
//--- the cards' COUNT COLOR row does it — the colour the row holds now, then the
//--- palette's own first row (`QuickPalColor(i)` = `BioPal(i)` = `BioPickColor(0,i)`,
//--- the cards' same eight), then a `+` that opens the ONE picker: the strip's
//--- colour board, which keeps the HEX field, the 64-cell page, RECENT and the
//--- opacity bar. One place for a colour, and its face is a swatch (P-DRAW-24).
//--- GEOMETRY, one 42px row of the strip's own 280 cell: 24 + 4 + 8*24 + 7*4 + 4 +
//--- 22 = 274, from `DSTRIP_GEAR_PAD` (16) → +290, inside the plate's 296. The
//--- COUNT is the CARDS' own `PNL_QSW_N`, not a second number.
#define DSTRIP_GEAR_SWQ_N    PNL_QSW_N    // 8 — the cards' own quick count
#define DSTRIP_GEAR_SWQ_CELL 24           // ds_swatch24's native canvas
#define DSTRIP_GEAR_SWQ_GAP  4
#define DSTRIP_GEAR_SWQ_PREV 24           // the block wearing the colour this row owns
#define DSTRIP_GEAR_SWQ_PLUS 22           // the "+" chip (pnl_chip + gl_plus_m)
//--- the GRID's own kinds (`s_dsGGKind`). 1 is the chip `DrawStripGearGridChips`
//--- writes; these three are P-DRAW-118's colour row, and every cell of it rides the
//--- same seat arrays the paint, the hit test and the tool walk.
#define DSTRIP_GRG_SWATCH 0   // a colour cell — its colour is in s_dsGGC[g]
#define DSTRIP_GRG_PREV   2   // the row's own colour, big: tap opens the board
#define DSTRIP_GRG_PLUS   3   // "+" — the same opener
#define DSTRIP_GEAR_LVLBLK 5   // P-DRAW-117: a long LEVEL list opens a block every
                               // 5 rows, so the wide pass can split INSIDE the list
                               // while no group header ever leaves its own content.
//--- P-DRAW-32 (2026-09-24) — THE SETTINGS PANEL IS ITS OWN CARD. User order:
//--- «پنل تنظیمات از استریپ جدا باشه». It used to be the strip's plate GROWING
//--- tall (one window wearing both), so a settings panel meant the toolbar itself
//--- became a tower. It is now a separate surface at its own origin (`s_dsGEX` /
//--- `s_dsGEY`): its own 9-slice plate, its own placement, its own carry — the
//--- strip stays the compact quick row it is. The arithmetic that makes the nine
//--- slice reusable is this constant: the plate's height must read `48 + 42k`
//--- (the skin's own law, P-DRAW-29) and the panel's fixed part is head 56 +
//--- foot 48 + this air, so the height is `104 + AIR + 42R`. AIR is 0 and the law
//--- is therefore EXACTLY the cards' own `56 + n*42 + 48` (P-DRAW-78b) — every
//--- content row lands on a card row and one bake carries the plate. Change this
//--- and the gear falls back to the flat legacy rect (DrawStripSkinK refuses a
//--- plate off the grid).
//--- P-DRAW-117 (2026-10-01): the TAB ROW is retired, so the second addend is the
//--- head alone — `DSTRIP_GEAR_GRID_TOP` is 56 where it used to be 98. The AIR's
//--- number did not move; its readers did: one 42px band left the panel, so the
//--- same content now needs one row fewer and `gh` reads `104 + 42R`.
//--- RETIRED (2026-09-29, P-DRAW-78b): the air was the make-up gap between a 42px
//--- foot band and the cards' 48px footer. The foot band is 48 now (DSTRIP_GEAR_FOOT_H,
//--- whose own ghost face reaches fy0+46 and needs the room), so the card's footer is
//--- already paid for and the 6px was a SECOND count of it: every tab stood 6px over
//--- the cards' law, `cardExact` was false on all four, and the plate fell to the
//--- composed W body on every tab instead of one baked card. Kept at 0 rather than
//--- deleted so the retired law stays readable next to the number that replaced it.
#define DSTRIP_GEAR_AIR 0    // head 56 + 42R + foot 48 + this = 104 + 42R: EXACTLY
                             // the cards' own law (56 + n*42 + 48). The retired
                             // values are the record: 34 was the TAB-ERA air
                             // (140 + 34 = 174 ≡ 48 mod 42, and the tabs are gone),
                             // 6 was the double count of the cards' footer (78b),
                             // and either put every group's height off every bake.
//--- P-DRAW-69: THE FIRST 42px CELL OF EACH SURFACE'S OWN BODY. The cards have ONE
//--- grid — the row pitch — and the plate's ramp bands ride it, so a row's face IS
//--- the band under it. The strip's first popover row and the board's first grid row
//--- both land on the ramp's own start, the panel's on its head (56) — the tab
//--- band's 42 above it is retired (P-DRAW-117).
#define DSTRIP_STRIP_GRID_TOP 44
#define DSTRIP_STRIP_BODY_TOP (DSTRIP_SKIN_TOPT - DSTRIP_SKIN_M)   // 44 — the cap's own content
#define DSTRIP_BOARD_GRID_TOP 44
#define DSTRIP_GEAR_GRID_TOP  (DSTRIP_GEAR_HEAD_H)   // P-DRAW-117: no tab row — the
                               // panel's first cell is the group list's own top row
//--- P-DRAW-70: WHERE A CARD'S BODY STARTS. `pnl_card7.bmp` content row 0 and 1 are
//--- the rim (#2C3444) and row 2 is the first body row (#1E242F) — measured. A plate
//--- that wears the card's ramp has to start its own body on the same row, or its
//--- baked 44px cap ramp shows through and the surface is 5-10 units dark.
#define DSTRIP_BODY_TOP 2
//--- the panel's default spot is BESIDE the strip's plate, never on it (P-DRAW-31's
//--- rule: no two surfaces on one pixel) — this is the air between them.
#define DSTRIP_GEAR_GAP 20   // must be >= DSTRIP_SKIN_BOTT(18) + DSTRIP_SKIN_M(14) - strip_h_remainder to avoid skin overlap
#define DSTRIP_GEAR_SECTION_MAX 8
//--- P-DRAW-30 (2026-09-24) — THE GEAR WEARS THE CARDS' WIDE RULE. Every settings
//--- surface in this project is a 312 card that turns into TWO 312 slots side by
//--- side once it carries more than ten rows (BiotakPanels.mqh `PNL_WEL` /
//--- `PNL_WIDE_WEL` / `PNL_COL_DX` / `PNL_WIDE_MIN_ROWS`); the gear panel was the
//--- one surface that never did, so its tall tabs (Style is 13 rows, a fibo's
//--- Levels up to 20) grew a single narrow column taller than the window and
//--- read as nothing like the cards. SAME numbers here: two 312 slots, 16px side
//--- pads, the middle 32px is the two pads back to back — so a column's content
//--- is the very same 280 the narrow layout always used and every existing
//--- block metric (swatch 28, chip 64, row 42) keeps its arithmetic.
#define DSTRIP_GEAR_W2   (2*PNL_WEL)   // P-DRAW-116: TWO cards side by side, so the wide width IS the card width twice
#define DSTRIP_GEAR_COL  312   // a block's x shift for the right column
#define DSTRIP_GEAR_WIDE_ROWS 10 // PNL_WIDE_MIN_ROWS parity: > 10 rows goes wide
#define DSTRIP_GEAR_BLK_MAX 12 // section blocks one tab may open (<= SECTION_MAX + air)
#define DSTRIP_RECENT_MAX 5    // the trader's own recent colours
#define DSTRIP_UNDO_MAX  32    // single-step undo: members covered
#define DSTRIP_UNDO_LV   32    // ... and fibo levels on the held drawing
#define DSTRIP_HOVER_POP_BASE 1000 // popover colour cells offset from gear cells
#define DSTRIP_HOVER_REC_BASE 2000 // TV parity: the board's RECENT band cells
#define DSTRIP_GRIP_MS   30    // the grip carry's own cadence (BkStripFollow parity)
//--- P-DRAW-75 (2026-09-28): the two-line ink gap, MEASURED off the cards' own
//--- header — title 12..24 over subtitle 35..43, so 11 of air in the middle (the
//--- number P-UI-131d took off the user's «از وسط چسبیده»). This module wore the
//--- scale's 6, which left the panel's head the one glued header in the product; at
//--- 11 `StrapInkY2` returns the cards' own 12 and 35 (A-12: the rule moved down).
#define DSTRIP_INK_GAP   11
//--- P-DRAW-75: a row's label→control gap and its label's point size — the cards'
//--- `PNL_ROW_GAP 10` / `PNL_PT_LBL 9`, i.e. B-02's floor, named here because
//--- include 97 cannot read 116.
#define DSTRIP_ROW_GAP   10
#define DSTRIP_GEAR_LBL_PT PNL_PT_LBL   // P-DRAW-116: the cards' own row-label point size
//--- P-DRAW-83: A CAPTION THAT SHARES ITS ROW WITH A CONTROL NAMES ITS CONTROL'S
//--- SEAT. The caption draws at `DSTRIP_GEAR_PAD + 14` (the cards' own row-label
//--- x, BiotakPanels 6007's `+16+14`) and the field starts at the seat the caption
//--- measured — 14 was a bare literal in the paint, so `DrawStripGearCapW` never
//--- counted it: the field began 30px INTO its own caption (label 30..76, field from
//--- 56), the hex text sat under the word that names it and the caption's own hit box
//--- covered the field's first 20px. One name for the one number, and the seat is
//--- `CAP_DX + the label + the gap` so the two can never disagree again.
#define DSTRIP_GEAR_CAP_DX 14
//--- 14 = the cards' caption x inside the row (PNL_PAD_X + 14 is 30, less the pad
//--- already in the origin). One owner of the caption's own seat.
#define DSTRIP_GEAR_CAP_X  (DSTRIP_GEAR_PAD + DSTRIP_GEAR_CAP_DX)
//--- P-DRAW-77: THE CARDS' OWN ROW SEATS, SPELLED ONCE HERE. Every number is the
//--- card's own constant (BiotakPanels 568/586/6155/6158), restated because
//--- `PNL_*` does not exist in this file (BiotakPanels is included AFTER it).
//--- 10 = (42-22)/2 chip+switch top · 14 = PNL_LBL_Y · 8 = the label's own gap
//--- after the chip · 40 = PNL_SW_W. One table, so the panel cannot drift from
//--- the card it stands beside a unit at a time.
#define DSTRIP_CARD_CHIP_Y 10
#define DSTRIP_CARD_LBL_Y  14
//--- P-DRAW-66: the quick row's THREE GROUPS — identity | values | commands. A
//--- separator is a 1x20 hairline centred in the row with 8 air on each side, so
//--- the chrome never reads as one more value; the head's air is the tight step.
#define DSTRIP_HEAD_AIR   8
#define DSTRIP_SEP_W      1
#define DSTRIP_SEP_H     20
#define DSTRIP_SEP_AIR    8
//--- P-DRAW-66: the command group's ids and count, moved UP from the layout block
//--- so the state block can size its own seat array by the count (one owner).
#define DSTRIP_QUICK_CAP 8
#define DSTRIP_ACT_MORE 0
#define DSTRIP_ACT_GEAR 1
#define DSTRIP_ACT_PIN 2
//--- P-BK-111 (2026-10-09) — THE SIDE IS THE USER'S TO TURN. It sits in the COMMAND
//--- group, not the quick-slot group, and that placement is the decision: the quick slots
//--- are the served drawing's own PROPERTIES (DRAW_SLOT_*, read and written on the object
//--- itself, kind-dependent), and a side is not a property of any drawing — it is a call
//--- on one Base Box, owned by the knot layer. So the cell is a fixed command like gear /
//--- bin, it widens the row by one seat (the layout derives the seats from DSTRIP_ACT_N),
//--- and on a drawing that is not a Base Box it paints, says so, and does nothing.
#define DSTRIP_ACT_DIR 3
#define DSTRIP_ACT_DEL 4
#define DSTRIP_ACT_N 5
//--- P-DRAW-29 (2026-09-24) — the plate skin's own metrics (define-before-use:
//--- PointInside and the clamps read them far above the painters). The plate's
//--- height is ALWAYS 48+42k, so one top cap (margin + 44) + k mid bands (42)
//--- + one bottom cap (4 + margin) composes every height; middles crop to every
//--- width (baked wide, MT4 crops a smaller XSIZE/YSIZE, never stretches).
#define DSTRIP_SKIN_M      PNL_MARGIN  // P-DRAW-116: the card bake's own transparent fringe
#define DSTRIP_SKIN_CAP    28    // corner cap width (margin + radius)
#define DSTRIP_SKIN_EDGE   15    // mid-row side strip (margin + 1px border)
#define DSTRIP_SKIN_TOPT   58    // top cap: margin + 44 (quick row + gap)
#define DSTRIP_SKIN_BOTT   18    // bottom cap: 4 + margin
#define DSTRIP_SKIN_MID    42
#define DSTRIP_SKIN_MIDW   640   // baked middle width (covers s_dsW <= 660)
#define DSTRIP_SKIN_MAXK   24    // baked mid strips are 24 bands tall
#define DSTRIP_SKIN_MAXW   660   // wider than any kind's quick row + badge
//--- P-DRAW-17: how far the hand may travel between press and release and still
//--- count as a CLICK. Past it the gesture was a DRAG - the user moving the
//--- drawing, or MT4's own native drag - and a drag must not summon the strip.
#define DSTRIP_CLICK_SLOP 8   // px of press->release travel (P-UI-113d: a release past
                              // this ended a DRAG - never the outside-click dismissal)
//--- gear tabs (0 = shut)
#define DSTRIP_GEAR_STYLE 1
#define DSTRIP_GEAR_LEVELS 2   // fibo family; TEXT/ARROW see MARK instead
#define DSTRIP_GEAR_MARK 2     // same seat as LEVELS (one tab at a time by kind)
#define DSTRIP_GEAR_TPL 3
#define DSTRIP_GEAR_STRIP 4
#define DSTRIP_GEAR_PAINT 5   // P-DRAW-65: the colours + the interior moved OFF Style —
                             // the tab that carried FOUR sections was the one that forced
                             // the 624-wide plate on every kind (B-08/B-10)
#define DSTRIP_GEAR_GRP_MAX 5  // group ids one kind may show at once (0 = shut)
//--- more-popover row kinds
#define DSTRIP_MK_APPLYALL 1
#define DSTRIP_MK_PRESET 2     // arg = preset index
#define DSTRIP_MK_SAVE 3
#define DSTRIP_MK_DUPE 4
#define DSTRIP_MK_UNDO 5
#define DSTRIP_MK_SLOT 6       // arg = overflow value slot (opens its grid)
#define DSTRIP_MK_BOX50 7      // P-DRAW-21: the box 50% line toggle (rect only)
#define DSTRIP_MK_BOXEXT 8     // P-DRAW-22: the box extend cycle (rect only)
#define DSTRIP_MK_FILL50 9     // P-DRAW-64: the interior ON at 50% tone, one tap
#define DSTRIP_FILL50_TONE 50  // ...the tone that row means

//--- P-DRAW-09c: the strip's palette. These are the settings cards' OWN tokens
//--- (CARD #1D222C, FIELD #181D27, LINE #222832, LABEL #CBD4E2, MUTED
//--- #8C96A6, ACCENT #FFC247, aInk #1A1206), and their owner — BiotakPanels.mqh
//--- — is included AFTER this module (P-BUILD-01's include order; MQL4 is
//--- define-before-use), which is why they used to be mirrored here as literals.
//
// P-UI-69b (2026-09-25): they are ALIASES now. The ink moved DOWN to
// ConstantsAndEnums.mqh (include #1 — below BOTH this module and the panels),
// so the mirror is gone and every name below still resolves here. Nine of the
// twelve were byte-for-byte duplicates of `PNL_CLR_*`; two tables that agree
// today are two tables that disagree tomorrow. The two inks that are the
// strip's own — a destructive action needs its own colour — stay literal.
#define DSTRIP_CLR_PANEL   BIO_CLR_PANEL
#define DSTRIP_CLR_CARD    BIO_CLR_CARD
#define DSTRIP_CLR_FIELD   BIO_CLR_FIELD
#define DSTRIP_CLR_FIELD_BD BIO_CLR_FIELD_BD
#define DSTRIP_CLR_FOOT    BIO_CLR_FOOT
#define DSTRIP_CLR_LINE    BIO_CLR_HAIRLINE
#define DSTRIP_CLR_LABEL   BIO_CLR_LABEL
#define DSTRIP_CLR_TITLE   BIO_CLR_MUTED
#define DSTRIP_CLR_VALUE   BIO_CLR_INK
#define DSTRIP_CLR_ACCENT  BIO_CLR_ACCENT
#define DSTRIP_CLR_ACCENT2 BIO_CLR_ACCENT2
#define DSTRIP_CLR_ACCENTT BIO_CLR_ACCENT_INK
#define DSTRIP_CLR_VER_BG  C'62,55,49'
#define DSTRIP_CLR_VER_BD  C'94,82,56'
//--- P-DRAW-66: `DSTRIP_CLR_DEL_BG` (C'58,26,30') is RETIRED with the loud bin —
//--- the quick row's cell and the foot's button wear the ghost face now and the
//--- red INK is the destructive cue. Written as prose, not as a define: a token
//--- nobody reads is catalogue 21's dead rung one layer up.
#define DSTRIP_CLR_DEL_INK C'255,138,138'
//--- P-DRAW-11: the "this cell has a list" rim (see the header block: rim = has
//--- a picker, face = is on — a text chevron renders as "?" in Wine fonts).
#define DSTRIP_CLR_PICK    C'62,72,92'

static string   s_dsObj  = "";       // the drawing this strip serves (the held one)
static EDrawKind s_dsKind = DK_NONE; // its kind, resolved once per open
static int      s_dsX    = 0;
static int      s_dsY    = 0;
static int      s_dsW    = 0;        // the width of THIS kind's strip (set on open)
static int      s_dsH    = 0;        // plate height: quick row + open blocks
static int      s_dsN    = 0;        // quick value/toggle cells on screen now
static bool     s_dsOpen = false;
static bool     s_dsPinned = false;  // P-DRAW-13: pin — outside click won't dismiss
//--- P-DRAW-41 (2026-09-25) — THE PLATE HAS A HOME. Reported: «پنل روی خوده ابجکت
//--- ظاهر میشه اصلا جالب نیست و تجربه کاربری بدی داره». A surface that re-places
//--- itself beside the drawing it serves cannot win: when the drawing fills the
//--- window EVERY candidate sits inside the work and the placer only picks the
//--- least-bad one. So the strip stops chasing — the first open measures the
//--- drawing ONCE and that answer becomes its home (`-1` = not measured yet).
//--- The old follow pair (`s_dsManual`/`s_dsAX`/`s_dsAY`) went with the chase.
static int      s_dsHomeX = -1, s_dsHomeY = -1;
//--- P-DRAW-13: the shell layout, computed by ONE pass (DrawStripLayout) and read
//--- by the painter, the hit test and the grip carry, so a cell's face and its
//--- gap can never be computed twice and disagree.
static int      s_dsCX[DSTRIP_MAX_SLOTS];
static int      s_dsCW[DSTRIP_MAX_SLOTS];   // the name is measured; icons are CELL
static int      s_dsBadgeW = 0;
//--- P-DRAW-66: the head's own x and the two group separators, computed once by
//--- the layout so the painter, the hit test and the carry can never disagree.
static int      s_dsBadgeX = 0;
static int      s_dsSepX[2];
static int      s_dsActX[DSTRIP_ACT_N];
//--- DIAG-135 (2026-10-02) — THE ROW-BLANK SIGNATURE. The paint checks its own
//--- invariant (a reserved cell that painted nothing) and writes ONE line per DISTINCT
//--- state; this string is what makes «one line per state» true, so a panel that stays
//--- sick writes once instead of on every repaint, and a panel that recovers re-arms.
//--- File scope for the same reason the z-ladder is: it must outlive the paint call.
static string   dsWitnessSig = "";
//--- P-DRAW-08k/08j (open-guard) RETIRED with the hold (DRHOLD-OFF, 2026-09-23):
//--- the guard existed because the hold fired while the button was still DOWN
//--- and its release CLICK needed swallowing. Right-click opens ON the release
//--- event itself, so there is nothing left to swallow — kept as history.
//--- P-UI-113c (2026-09-23): AND IT IS BACK, because the LEFT HOLD is the trigger
//--- again and a hold FIRES WHILE THE BUTTON IS STILL DOWN - so its release lands
//--- on the drawing = outside the strip. The guard's state and owners live with
//--- the hold (`s_dsOpenerUntil` below), one window per opening press.
//--- P-DRAW-11: the open popover (ONE at a time, BaseKnot parity): a slot id,
//--- or DSTRIP_MORE for the more-popover. The gear panel is a separate seat
//--- (s_dsGear) and shuts the popover when it opens.
static int      s_dsPicker = DSTRIP_PICK_NONE;
static int      s_dsTpl[DK_COUNT];               // last applied preset per kind
static bool     s_dsTplNameArmed = false;      // P-DRAW-25: save is armed, name edit open
static int      s_dsGearMem[DK_COUNT];         // P-DRAW-26: last gear tab per kind (templates at hand)
static int      s_dsPN = 0;                      // popover rows on screen now
static int      s_dsPY[DSTRIP_PICK_MAX];         // row tops (rows are full-width)
static int      s_dsPHexY = -1;                  // color popover hex band top (-1 = none)
static int      s_dsPHeadY = -1;                 // color popover header band top (-1 = none)
static int      s_dsPRecY = -1;                  // color popover recents band top (-1 = none)
static int      s_dsPOpY = -1;                   // its OPACITY band top (P-DRAW-48)
static bool     s_dsOpGrab = false;              // the bar's own drag is live
static uint     s_dsOpMs = 0;                    // its cadence (DSTRIP_GRIP_MS)
//--- P-DRAW-64 (2026-09-27) — THE PALETTE SCRUB. User order: the live preview may
//--- come back ONLY while the left button is held and dragged across the cells, and
//--- the release applies what is under the pointer — never on a mere hover (that
//--- first cut wrote the PURE colour on the chart and cost the tuned tone). The
//--- gesture owns the view for its length and names itself in `DrawStripViewOwned`.
#define DSTRIP_PAL_TAIL_MS 400                  // the twin release channel's window
static bool     s_dsPalGrab = false;             // a scrub is live
static int      s_dsPalCell = -1;                // its last previewed cell
static uint     s_dsPalMs = 0;                   // its hit-test cadence (DSTRIP_GRIP_MS)
static uint     s_dsPalDoneMs = 0;               // the release that already applied
static string   s_dsPalName[DRAW_SEL_MAX];       // its target: the SERVED drawing (P-DRAW-09b retired)
static int      s_dsPalN = 0;
static bool     s_dsHexFocus = false;            // the HEX field is being typed in
//--- P-DRAW-48 (2026-09-26): THE COLOUR BOARD IS ITS OWN CARD. User order:
//--- «پاپ بشه مثل همین» — the reference board floats: its own rounded plate with
//--- the family's shadow, carried by its header, pinned to the plate or left
//--- where the hand put it. It is a THIRD 9-slice family (2) at its own rect,
//--- the same architecture the settings panel took in P-DRAW-32 — the strip's
//--- plate stops growing under it, and the popover bands are measured from the
//--- BOARD's origin (`s_dsBX/s_dsBY`), never the strip's.
static int      s_dsBX = 0, s_dsBY = 0, s_dsBW = 0, s_dsBH = 0;   // the board's own rect
static bool     s_dsBManual = false;             // the hand placed the board: keep that spot
static bool     s_dsBDock = true;                 // pinned: the placer follows the strip
static bool     s_dsBGripLive = false;            // its header carries the BOARD
static int      s_dsBGripDX = 0, s_dsBGripDY = 0;
static uint     s_dsBGripMs = 0;
//--- P-DRAW-75 (2026-09-28): `s_dsBPlateLive` is GONE. "Is family 2 on the chart"
//--- is a fact the object list already answers, and the bool was a second copy of it
//--- (H-06, A-10): a plate a path painted while the flag read false, or one the
//--- P-DRAW-42 orphan sweep removed while it read true, left the copy answering
//--- about a plate that was not there. The two purges that read it are now ONE
//--- decision above the branches, and it asks `ObjectFind` (see DrawStripPaint).
#define DSTRIP_BOARD_HDR 44                      // the header band rides the skin's own top cap
//--- P-DRAW-64: 26, not 22 — B-05's 24 px floor was the thing a user reaching for
//--- the ✕ at the end of a transparency edit kept missing («نمیتونم بسته بکنم»).
#define DSTRIP_PHEAD_XW 26                       // header close button seat
#define DSTRIP_BPIN_XW   26                      // its pin (dock/undock) seat, one step left
#define DSTRIP_PREC_LW  52                       // "RECENT" label seat (its own band's left column)
#define DSTRIP_POP_EDIT_H 22                     // the board's HEX field (OBJ_EDIT) height
//--- P-DRAW-48: the OPACITY bar's own metrics — the cards' tracks, verbatim
//--- (BiotakPanels PNL_TRK_H/KNOB), because the preview's `.opwrap` and the panels'
//--- TRANSPARENCY rows are ONE language and a second set of numbers is a second look.
#define DSTRIP_TRK_H      8                      // the bed's height
#define DSTRIP_KNOB_W    10                      // the knob's seat
#define DSTRIP_KNOB_H    12
#define DSTRIP_OP_VW     38                      // the readout's seat (the preview's .ov 34px)
//--- P-DRAW-66: the HEX field's own seat inside the band it shares with the bar.
#define DSTRIP_HEX_W     96
static int      s_dsMoreKind[DSTRIP_PICK_MAX];   // DSTRIP_MK_* per more-row
static int      s_dsMoreArg[DSTRIP_PICK_MAX];    // preset index / slot id
static color    s_dsRecent[DSTRIP_RECENT_MAX];   // the trader's recent colours
static int      s_dsRecentN = 0;
//--- P-DRAW-13: the gear panel (0 = shut, else DSTRIP_GEAR_*). Tabs after the
//--- content: gear rows live in GR/GRI/GRT, grid cells in GG/GGI, tabs in GT,
//--- foot in GF, edits in GE — one namespace per role so painters never share.
static int      s_dsGear = 0;
static int      s_dsGRN = 0;                     // gear list rows on screen
static int      s_dsGRY[DSTRIP_GLIST_MAX];
static int      s_dsGRCol[DSTRIP_GLIST_MAX];     // P-DRAW-30: its column (0 left · 1 right)
static int      s_dsGRKind[DSTRIP_GLIST_MAX];    // 1 toggle-slot · 2 preset · 3 save ·
                                                 // 4 level-row · 5 levels All/None · 6 vis ·
                                                 // 7 default-learn · 8 option-row
static int      s_dsGRArg[DSTRIP_GLIST_MAX];     // slot / preset idx / packed
static int      s_dsGGN = 0;                     // gear grid cells on screen
static int      s_dsGGX[DSTRIP_GRID_MAX];
static int      s_dsGGY[DSTRIP_GRID_MAX];
static int      s_dsGGW[DSTRIP_GRID_MAX];
static int      s_dsGGH[DSTRIP_GRID_MAX];
static int      s_dsGGKind[DSTRIP_GRID_MAX];     // 0 swatch (colour in GGC) · 1 chip
static int      s_dsGGSlot[DSTRIP_GRID_MAX];
static int      s_dsGGArg[DSTRIP_GRID_MAX];
static color    s_dsGGC[DSTRIP_GRID_MAX];
//--- P-DRAW-64: the highlight is the CELL's (the rim), so there is no preview
//--- state left to carry — one index is the whole of it. The `s_dsColorHoverN/
//--- Name/Color` trio went with the retired chart preview (this note is why a
//--- future reader must not re-add them without re-reading the report above).
static int      s_dsColorHoverCell = -1;
static int      s_dsGearGrp[DSTRIP_GEAR_GRP_MAX + 1];   // group ids shown (count in [0])
//--- P-DRAW-117: `s_dsGear` IS THE OPEN GROUP (never 0 while the panel is open), so
//--- every reader that asks `s_dsGear != 0` keeps its answer; this flag is the ONE
//--- new fact — the user collapsed the open group's settings with its own header,
//--- and the panel is then the group list alone.
static bool     s_dsGearCollapsed = false;
static int      s_dsGearHeadY = -1;
static int      s_dsGearSecN = 0;
static int      s_dsGearSecY[DSTRIP_GEAR_SECTION_MAX];
static int      s_dsGearSecCol[DSTRIP_GEAR_SECTION_MAX];
static string   s_dsGearSecText[DSTRIP_GEAR_SECTION_MAX];
//--- P-DRAW-66: the caption's own row can carry its CONTROL (C-05: label left,
//--- value right). `s_dsGearSecCX` is that control's x inside the column (-1 = the
//--- caption owns its band alone, the retired two-rows-per-setting shape), and the
//--- two edit arrays are a hex field's own seat and width inside that seat.
static int      s_dsGearSecCX[DSTRIP_GEAR_SECTION_MAX];
static int      s_dsGearEditX[5];
static int      s_dsGearEditW[5];
//--- P-DRAW-30: the WIDE rule's own state. `s_dsGearW` is THIS tab's gear width
//--- (resolved once per layout, read by the head/track/sections painters), and
//--- `s_dsGearBlk*` is the block map the balance split is measured on — one entry
//--- per `DrawStripGearSection()`, i.e. per "header + the content under it".
static int      s_dsGearW = DSTRIP_GEAR_W;
//--- P-DRAW-32: the panel's OWN origin (absolute screen px, its top-left corner)
//--- and height. Every gear painter reads these instead of the strip's plate, so
//--- "where the panel is" has one answer and the two surfaces can never share a
//--- coordinate space again.
static int      s_dsGEX = 0, s_dsGEY = 0;
static int      s_dsGearH = 0;
static bool     s_dsGearManual = false;   // the hand placed the panel: keep its spot
//--- P-DRAW-88 (2026-09-29): THE PANEL STAYS WHERE IT IS. DrawStripPlaceGear's
//--- 8-position scorer ran on EVERY paint, so every tab switch (314 <-> 524 tall)
//--- re-scored from scratch and could crown a different corner — the panel jumped
//--- to "somewhere else" on the exact gesture the user uses most. User order:
//--- «همون‌جا باز بشه». Once placed, a paint only CLAMPS to the window (same as
//--- the manual carry above); a FRESH open — or a different drawing — scores anew.
//--- One flag + the served name, cleared where the panel dies (DrawStripGearClose).
static bool     s_dsGearPlaced = false;
static string   s_dsGearPlacedObj = "";
//--- P-DRAW-75: `s_dsGearPlateLive` went with the board's — the panel's plate is on
//--- the chart iff its own bg object is, and the paint asks.
//--- P-DRAW-89: retired. The plate had four transparency levels; the last reader of
//--- this index was `StrapBodyTone`, and it read the CHART's background through it.
static int      s_dsPlateTIdx = 0;
static int      s_dsGearW0 = 0;           // its outer width (content + pads), for the plate
static int      s_dsGearBlkN = 0;
static int      s_dsGearBlkY[DSTRIP_GEAR_BLK_MAX];
static int      s_dsGearEditY[5];                // edit rows (border-hex/fill-hex/level-add/
                                                 // caption/tpl-name — P-DRAW-64 appended 1)
static int      s_dsGearEditCol[5];              // P-DRAW-30: its column
static int      s_dsGearFootY = 0;
static bool     s_dsVis[DK_COUNT][DRAW_SLOT_N];  // Strip tab: per-slot visibility
static bool     s_dsVisInit = false;
//--- P-DRAW-13: the grip carry (screen-object drag). Screen objects are
//--- SELECTABLE=false, so MT4 never drags our plate for us and P-LM-11's race with
//--- the terminal's own drag cannot happen.
static bool     s_dsGripLive = false;
static int      s_dsGripDX = 0, s_dsGripDY = 0;
static uint     s_dsGripMs = 0;
//--- P-DRAW-32: and the SETTINGS PANEL carries itself the same way (its header is
//--- its handle), with its own offset and its own cadence — one cursor, one of the
//--- two gestures live at a time (`DrawStripGripWhich` answers which).
static bool     s_dsGGripLive = false;
static int      s_dsGGripDX = 0, s_dsGGripDY = 0;
static uint     s_dsGGripMs = 0;
//--- P-UI-113d (2026-09-23): AND THE CARRY TAKES THE PROJECT'S ONE VIEW LOCK for
//--- the length of the gesture (P-UI-53's law, P-UI-90's single owner). The chart
//--- BEHIND the plate stays live and CHART_MOUSE_SCROLL is ON by default, so a
//--- hand that wanders while carrying the plate PANS the view instead of moving
//--- the strip («با درگ استریپ چارت پشتش نباید تکون بخوره که درگ کردن نمیشه یا
//--- سخت میشه»). ONE ender owns the flag, so the acquire/release pair can never
//--- drift — and it lives in this block because `DrawStripClose`, defined below,
//--- must hand the view back (MQL4 reads a bare `void f();` prototype as an
//--- import, so owners are DEFINED before their first use here, never declared).
#endif // DRAW_STRIP_HEAD_MQH
// DrawStrip_Base.mqh - DrawStrip split 2026-09-29: exact lines 678-1460 of DrawStrip.mqh, byte-identical, zero renames.
#ifndef DRAW_STRIP_BASE_MQH
#define DRAW_STRIP_BASE_MQH

//--- P-DRAW-126 (2026-10-01) — THE DIAG CHANNEL DOES NOT WAIT FOR THE TERMINAL.
//--- MEASURED (2026-10-01 20:15:20): the live terminal (`AMarkets - MetaTrader 4`,
//--- data folder `A1660DA4...`, one process up since 15:10:36) showed a full
//--- `20:03:44` frame in its Experts window while `MQL4\Logs\20261001.log` still
//--- ended at `20:01:38.319` — a probe for `20:03:44` counted ZERO, and the file
//--- had not grown in fourteen minutes. MT4 buffers its own journal in RAM and
//--- flushes on its own schedule, so a reader that opens only that file is always
//--- behind the tab it is meant to witness. The diag channel therefore mirrors
//--- every line into a file it owns and flushes per line: `FileFlush` is the one
//--- write whose arrival does not depend on the terminal's buffer.
//--- `tools/diag-live.py` reads THIS file (`<data folder>\MQL4\Files\`); the
//--- Experts log is never the oracle, only a fallback.
//--- P-LOG-3 (2026-10-01) — AND A FLUSH IS NOT ENOUGH IF THE HANDLE IS EXCLUSIVE.
//--- MEASURED 2026-10-01 21:52:50: the file WAS written and flushed
//--- (`biotak_diag_EURUSD.txt`, 62,965 bytes, mtime 21:52:50) — and every reader
//--- failed on it anyway: `open(path,'rb')` -> PermissionError 13, `cp`/`head` ->
//--- "Device or resource busy", `Get-Content` -> "being used by another process".
//--- A plain `FileOpen` in the terminal grants no share, so the bytes were current
//--- and unreachable at the same time: the channel could not be read by the very tool
//--- built to read it. `FILE_SHARE_READ` is the flag that lets another process open
//--- the handle the terminal holds (the stock `MQL4\Scripts\PeriodConverter.mq4`
//--- uses it), so each flushed line is now readable the moment it is written.
//--- P-LOG-3b (2026-10-01) — AND THE FILE IS PER CHART, NOT PER SYMBOL. MEASURED
//--- 21:52..21:58 with the panel open on EURUSD,M1 AND EURUSD,H1: `Symbol()` names
//--- both charts the same, so each instance opened its OWN handle to ONE path and
//--- wrote it from its own position. The file stopped growing (62,965 bytes at
//--- 21:52:50 and again at 21:58:51) while two charts were emitting whole frames,
//--- and the two frames the bytes actually held were both the M1 chart's (221 and
//--- 230 lines, matching the journal's EURUSD,M1 at 21:52:49/21:52:50) — the H1
//--- frames the screen was showing were nowhere in it. `ChartID()` is what
//--- separates two charts of one symbol, so the name carries it.
#ifdef DSTRIP_DIAG
void DrawStripDiagEmit(const string line)
{
   Print(line);
   static int dh = INVALID_HANDLE;
   if(dh == INVALID_HANDLE)
      dh = FileOpen("biotak_diag_" + Symbol() + "_" + IntegerToString(ChartID()) + ".txt",
                    FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(dh == INVALID_HANDLE) return;
   FileWrite(dh, line);
   FileFlush(dh);
}
#else
// P-UI-136 (2026-10-02): the symbol stays DEFINED when the switch is 0, because
// a drawing tool that witnesses its gestures (PathWitness, PathTool.mqh — the
// channel is borrowed by name, this file owns the handle) must not turn the
// whole unit's build into "function not defined" when the census is switched
// off. The fallback is the journal, never silence (AGENTS law 3).
// P-PERF-13 (2026-10-12) - THE CENSUS CHANNEL IS SILENT BY DEFAULT.
// Measured: thousands of Print-per-object/per-move lines on the live
// log, synchronous journal writes on the path they measure.
void DrawStripDiagEmit(const string line) { }
#endif

#ifdef DSTRIP_DIAG
//--- P-LOG-8 (2026-10-01) — THE AFTER-FRAME. The census is a snapshot taken at dump
//--- time; the SCREEN is later. The wide gear frame of the 2026-10-01 report read
//--- 91/91 PASS (seat, layer, text, back, win, corner) while the screenshot showed the
//--- panel's left column bare, and the whole-chart walk (P-LOG-7) named no cover at
//--- all — so the only question the model cannot answer is WHETHER THE STATE IT SAW
//--- IS STILL THE STATE ON THE CHART when the user screenshots it. A later writer that
//--- deletes, moves or re-rungs a name after the dump is invisible to every snapshot.
//--- So the dump stores what the census saw, and the NEXT paint pass walks that same
//--- name list again and prints only the DELTA: GONE (a later purge), MOVED (a later
//--- writer), NEW (a later cover inside the panel rect), and a `done` line that says
//--- the model survived unchanged when nothing moved. One flag, one pass, no cost.
#define DSTRIP_DIAG_SNAP 384
int    s_dsDiagAfter = 0;                     // 0 idle · 1 armed by the dump · 2 fired
int    s_dsSnapN = 0;
int    s_dsSnapRect[4];                       // bx0, by0, bx1, by1 at snapshot time
string s_dsSnapNm[DSTRIP_DIAG_SNAP];
int    s_dsSnapX[DSTRIP_DIAG_SNAP], s_dsSnapY[DSTRIP_DIAG_SNAP];
int    s_dsSnapW[DSTRIP_DIAG_SNAP], s_dsSnapH[DSTRIP_DIAG_SNAP];
int    s_dsSnapZ[DSTRIP_DIAG_SNAP], s_dsSnapB[DSTRIP_DIAG_SNAP];

void DrawStripDiagSnapRect(const int bx0, const int by0, const int bx1, const int by1)
{
   //--- P-LOG-8b: ONE census, ONE snapshot. The store must never carry a previous
   //--- frame's names: MEASURED on the first live AFTER (23:29:10) — the store held
   //--- 200 names (the narrow frame's 98 still in it) and the delta reported 50
   //--- MOVED / 36 GONE that were only the narrow→wide layout switch
   //--- (`GS0C was=1357,146 now=1357,188`), burying the signal this block exists for.
   s_dsSnapN = 0;
   s_dsSnapRect[0] = bx0; s_dsSnapRect[1] = by0; s_dsSnapRect[2] = bx1; s_dsSnapRect[3] = by1;
}

bool DrawStripDiagSnapAdd(const string nm, const int x, const int y, const int w, const int h,
                          const int z, const int back)
{
   if(s_dsSnapN >= DSTRIP_DIAG_SNAP || ObjectFind(0, nm) < 0) return false;
   s_dsSnapNm[s_dsSnapN] = nm;
   s_dsSnapX[s_dsSnapN] = x; s_dsSnapY[s_dsSnapN] = y;
   s_dsSnapW[s_dsSnapN] = w; s_dsSnapH[s_dsSnapN] = h;
   s_dsSnapZ[s_dsSnapN] = z; s_dsSnapB[s_dsSnapN] = back;
   s_dsSnapN++;
   return true;
}

int DrawStripDiagSnapIdx(const string nm)
{
   for(int i = 0; i < s_dsSnapN; i++) if(s_dsSnapNm[i] == nm) return i;
   return -1;
}

//--- P-LOG-8c (2026-10-01) — A CHART OBJECT'S SCREEN BOX IS NOT ITS XDISTANCE.
//--- `OBJ_RECTANGLE` / `OBJ_TREND` / zones answer `OBJPROP_XDISTANCE` with 0 (that
//--- property belongs to SCREEN objects), so the census's box test read `0,0` for
//--- them and the panel-rect test threw every one away — the one family that CAN
//--- cover this panel (a TH3 zone / BaseKnot box drawn in the foreground) was still
//--- invisible to the walk that exists to name a cover. Their real box is their
//--- TIME/PRICE anchors through `ChartTimePriceToXY`. Labels keep their anchor.
bool DrawStripCensusAnyBox(const string nm, const int oty,
                           int &ox, int &oy, int &ow, int &oh)
{
   if(oty == OBJ_LABEL || oty == OBJ_TEXT) return true;
   ow = DrawStripCensusSize(nm, oty, 0);
   oh = DrawStripCensusSize(nm, oty, 1);
   if(ow > 0 || oh > 0) return true;
   datetime t1 = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 0);
   double   p1 = ObjectGetDouble(0, nm, OBJPROP_PRICE, 0);
   datetime t2 = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 1);
   double   p2 = ObjectGetDouble(0, nm, OBJPROP_PRICE, 1);
   int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
   if(t1 == 0 || !ChartTimePriceToXY(0, 0, t1, p1, x1, y1)) return false;
   if(t2 == 0 || !ChartTimePriceToXY(0, 0, t2, p2, x2, y2)) { ox = x1; oy = y1; ow = 0; oh = 0; return true; }
   ox = (x1 < x2 ? x1 : x2); oy = (y1 < y2 ? y1 : y2);
   ow = (x2 > x1 ? x2 - x1 : x1 - x2);
   oh = (y2 > y1 ? y2 - y1 : y1 - y2);
   return true;
}

void DrawStripDiagAfterRun()
{
   s_dsDiagAfter = 2;
   int gone = 0, moved = 0;
   for(int i = 0; i < s_dsSnapN; i++)
   {
      string nm = s_dsSnapNm[i];
      if(ObjectFind(0, nm) < 0)
      {
         DrawStripDiagEmit("[drawstrip] AFTER GONE obj=" + nm);
         gone++;
         continue;
      }
      int x = (int)ObjectGetInteger(0, nm, OBJPROP_XDISTANCE);
      int y = (int)ObjectGetInteger(0, nm, OBJPROP_YDISTANCE);
      int z = (int)ObjectGetInteger(0, nm, OBJPROP_ZORDER);
      int bk = (int)ObjectGetInteger(0, nm, OBJPROP_BACK);
      if(x != s_dsSnapX[i] || y != s_dsSnapY[i] || z != s_dsSnapZ[i] || bk != s_dsSnapB[i])
      {
         DrawStripDiagEmit("[drawstrip] AFTER MOVED obj=" + nm +
                           " was=" + IntegerToString(s_dsSnapX[i]) + "," + IntegerToString(s_dsSnapY[i]) +
                           ",z" + IntegerToString(s_dsSnapZ[i]) + ",b" + IntegerToString(s_dsSnapB[i]) +
                           " now=" + IntegerToString(x) + "," + IntegerToString(y) +
                           ",z" + IntegerToString(z) + ",b" + IntegerToString(bk));
         moved++;
      }
   }
   int fresh = 0;
   int n = ObjectsTotal(0, -1);
   for(int oi = 0; oi < n; oi++)
   {
      string on = ObjectName(0, oi, -1);
      if(on == "" || DrawStripDiagSnapIdx(on) >= 0) continue;
      int oty = (int)ObjectGetInteger(0, on, OBJPROP_TYPE);
      int ox = (int)ObjectGetInteger(0, on, OBJPROP_XDISTANCE);
      int oy = (int)ObjectGetInteger(0, on, OBJPROP_YDISTANCE);
      if(ox + 8 < s_dsSnapRect[0] || ox > s_dsSnapRect[2] ||
         oy + 8 < s_dsSnapRect[1] || oy > s_dsSnapRect[3]) continue;
      DrawStripDiagEmit("[drawstrip] AFTER NEW obj=" + on + " type=" + IntegerToString(oty) +
                        " xy=" + IntegerToString(ox) + "," + IntegerToString(oy) +
                        " z=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_ZORDER)) +
                        " back=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_BACK)));
      fresh++;
   }
   DrawStripDiagEmit("[drawstrip] AFTER done snap=" + IntegerToString(s_dsSnapN) +
                     " gone=" + IntegerToString(gone) + " moved=" + IntegerToString(moved) +
                     " new=" + IntegerToString(fresh) + " chartObjs=" + IntegerToString(n));
}

//--- P-LOG-9 (RETIRED 2026-10-02) — the probe labels asked MT4's own draw rule and
//--- the screen answered: P1 (content rung) and P2 (rung 1600) at the LEFT seat and
//--- P3 at the right all showed while the left column stayed bare until P-LOG-10, and
//--- the touch test's same-pixel write raised nothing — CREATE is the only raise.
//--- The labels are gone; the law and its record live in DrawStrip_GearPlate (P-LOG-10)
//--- and in contract §6 item 23.
#endif

//--- P-LOG-5 (2026-10-01) — THE CENSUS'S INK COLUMN BELONGS TO EVERY CAPTIONED
//--- OBJECT, NOT TO LABELS ONLY. MEASURED 2026-10-01 22:10
//--- (`biotak_diag_EURUSD_134342075006101685.txt`): the panel passed the diff 91/91
//--- while the ONE class the diff never tested was a button's own text — the census
//--- wrote `ink` for `OBJ_LABEL` only. The swatch row's captions (`1px`..`5px`,
//--- `Solid`..`D-Dot`) are BUTTON TEXT, so the report «بعضی ردیف‌ها متن نداره» could
//--- not be decided from the log at all: a LOST caption and a healthy face both read
//--- `ink=-`, and `diag-diff` reads that same column. A button answers OBJPROP_TEXT
//--- exactly as a label does, so the column carries both now. The helper lives HERE,
//--- not in `DrawStrip_GearB.mqh`, which stands at 1497 of the 1500-line ceiling
//--- (P-SIZE-1500).
string DrawStripCensusInk(const string nm, const int oty)
{
   if(oty != OBJ_LABEL && oty != OBJ_BUTTON) return "-";
   return "\"" + ObjectGetString(0, nm, OBJPROP_TEXT) + "\":" +
          IntegerToString((int)ObjectGetInteger(0, nm, OBJPROP_COLOR));
}

//--- P-LOG-6 (2026-10-01) — THE CENSUS'S BOX TEST IS THE OBJECT'S OWN BOX.
//--- MEASURED 2026-10-01 22:17 (`biotak_diag_EURUSD_134342075006101685.txt`): the
//--- panel's PLATE is painted on every open (`DrawStripGearPlate` -> `DrawStripSkinBmp`
//--- "PnlDrawS_Gbake" / `Gtop` / `Gmid*` / `Gbot`) and it appeared in NOT ONE of the
//--- 187 census lines. The walk took a bitmap label's box from `DrawStripResW/H` of its
//--- RESOURCE, and a name that table does not carry reads 0 — so the plate's box
//--- collapsed to a POINT at `gx-14, gy-14`, its own 14px margin, outside the panel
//--- rect on both axes, and every tile was skipped. The largest object the panel owns
//--- — and the ONE that can hide every control if its rung is wrong, which Skin.mqh's
//--- own P-DRAW-72 note records as a real past failure ("the bake sat ABOVE the tabs,
//--- the hex fields, the Interior switch and the foot") — was the one object the census
//--- could never print. So a diagnostic can answer "who is on top" only for the
//--- objects it is willing to look at. The object answers XSIZE/YSIZE itself (every
//--- writer here sets them); the resource table stays as the fallback for a face that
//--- carries none. Lives HERE, not in DrawStrip_GearB.mqh (1495 of the 1500-line
//--- ceiling, P-SIZE-1500) — and Skin.mqh's `DrawStripIsBg` is included AFTER GearB,
//--- so the census cannot ask it either.
int DrawStripCensusSize(const string nm, const int oty, const int axis)
{
   if(oty == OBJ_BUTTON || oty == OBJ_RECTANGLE_LABEL || oty == OBJ_EDIT ||
      oty == OBJ_BITMAP_LABEL)
   {
      int v = (int)ObjectGetInteger(0, nm, (axis == 0) ? OBJPROP_XSIZE : OBJPROP_YSIZE);
      if(v > 0) return v;
   }
   string bf = ObjectGetString(0, nm, OBJPROP_BMPFILE, 0);
   return (axis == 0) ? DrawStripResW(bf) : DrawStripResH(bf);
}

bool DrawStripCensusInPanel(const string nm, const int oty,
                            const int ox, const int oy,
                            const int bx0, const int by0, const int bx1, const int by1)
{
   int ow = DrawStripCensusSize(nm, oty, 0), oh = DrawStripCensusSize(nm, oty, 1);
   return !(ox + ow < bx0 || ox > bx1 || oy + oh < by0 || oy > by1);
}

void DrawStripGripRelease()
{
   // P-DRAW-32: either carry owns the lock — one release ends whichever is live.
   // P-DRAW-48: and the BOARD's carry is the third, the opacity bar's own drag the
   // fourth (four owners, ONE ender — the button-up net, the close and Esc all
   // come through here).
   if(s_dsGripLive || s_dsGGripLive || s_dsBGripLive || s_dsOpGrab || s_dsPalGrab)
      ChartViewLockRelease();   // P-UI-90: one release per acquire
   s_dsGripLive = false;
   s_dsGGripLive = false;
   s_dsBGripLive = false;
   s_dsOpGrab = false;
   s_dsPalGrab = false;
}
//--- P-DRAW-31 (2026-09-24) — THE STRIP PUBLISHES ITS PLATE. The cards' placement
//--- (`PnlComputePosition`) cannot see this module (included after us, MQL4 is
//--- define-before-use), so the plate's rect is handed over instead: one writer, from
//--- every path that moves, opens or closes the strip, cleared when it is off screen.
//--- `-1` is the "no strip" answer — the same contract `g_UIPanelR*` uses.
//--- P-DRAW-32: and the SETTINGS PANEL is published with it — the two surfaces are ONE
//--- occupancy for every reader (a card must clear both, and a fresh strip must clear
//--- both), so the rect handed over is their UNION while the panel is open. One
//--- contract, one writer, no second global to keep in sync.
// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-64 (2026-09-27) — TWO COLOUR CELLS, ONE BOARD. User order: «رنگ بوردر
// بشه جدا تنظیم کرد ... و fill همه جدا. یک بخش براش اضافه کن». The owner module
// declares `DRAW_SLOT_FILLCLR` (the interior); HERE it is a COLOUR CELL exactly like
// `DRAW_SLOT_COLOR` — own swatch, board and tone — so every surface asks these two
// questions instead of naming one slot. Which board is open stays `s_dsPicker`.
// ══════════════════════════════════════════════════════════════════════════
bool DrawStripIsColorSlot(const int slot)
{
   //--- P-DRAW-BODY-UI: the handle's own colour rides the same palette bridge,
   //--- so it is a colour cell too (same seats, no layout change).
   return (slot == DRAW_SLOT_COLOR || slot == DRAW_SLOT_FILLCLR ||
           slot == DRAW_SLOT_BODYCOLOR);
}
color DrawStripColorRead(const string nm, const int slot)
{
   return (color)(int)DrawSlotRead(nm, slot);
}
//--- what a colour CELL shows: the border cell stores and shows the pure colour,
//--- the interior cell shows the pixel the chart will wear (its own tone applied) —
//--- so the two cells are never two answers to one question.
color DrawStripColorFace(const string nm, const int slot)
{
   color c = DrawStripColorRead(nm, slot);
   if(slot != DRAW_SLOT_FILLCLR) return c;
   return DrawSlotRenderFillColor(nm, c);
}

// ══════════════════════════════════════════════════════════════════════════
// P-PAL-19 (2026-10-02) — THE STRIP ASKS THE CARDS' PALETTE. It has no colour
// board of its own any more: every other surface in this product edits a
// colour through ONE popup (BiotakPanels_PalA/PalB), and the strip was the last
// surface that painted a second one — the two then drifted (the board's own
// catalogue, its own recents, its own hex field), and every defect in it was a
// defect the cards' palette never had.
// The include order decides the shape: DrawStrip is include 99, the panels are
// 124, and MQL4 needs a definition BEFORE its use — so the strip cannot call
// `PalOpenKind` itself. It leaves a REQUEST (below); the entry's bridge line,
// which sees both, performs the open. One bridge, one direction, no prototype.
// ══════════════════════════════════════════════════════════════════════════
static string s_dsPalObj = "";        // the drawing the popup is editing
static int    s_dsPalSlot = DSTRIP_PICK_NONE;
static int    s_dsPalAskSlot = DSTRIP_PICK_NONE;   // the pending open, one click wide
static bool   s_dsPalRepaint = false;      // a pick owes the strip ONE frame (P-PAL-19f)
//--- P-LVL-COLOR (2026-10-04) — ONE LEVEL'S OWN COLOR. -1 = the slot's (whole
//--- drawing); >=0 = the stored level index on s_dsPalObj. The popup is the same
//--- cards palette (one palette, P-PAL-19); only the target is narrower.
static int    s_dsPalLevel = -1;

void DrawStripPalAsk(const int slot)
{
   if(!s_dsOpen || s_dsObj == "") return;
   DrawStripGearClose();
   s_dsPalObj  = s_dsObj;
   s_dsPalSlot = slot;
   s_dsPalAskSlot = slot;
   s_dsPalLevel = -1;
}
//--- a level row's swatch asks through here: same palette, one stored level.
void DrawStripPalAskLevel(const int slot, const int level)
{
   if(!s_dsOpen || s_dsObj == "") return;
   DrawStripGearClose();
   s_dsPalObj  = s_dsObj;
   s_dsPalSlot = slot;
   s_dsPalAskSlot = slot;
   s_dsPalLevel = level;
}
bool DrawStripPalTargetIsLevel() { return (s_dsPalLevel >= 0); }
int    DrawStripPalAsked()   { if(s_dsPalAskSlot == DSTRIP_PICK_NONE) return -1;
                               int a = s_dsPalAskSlot; s_dsPalAskSlot = DSTRIP_PICK_NONE; return a; }
string DrawStripPalTargetObj()  { return s_dsPalObj; }
//--- P-PAL-19: the strip's own rect, for the one caller that places the popup beside
//--- it (the entry's bridge). Three lines, because a bridge that cannot say WHERE the
//--- strip is would park the palette in a corner — P-UI-98r's own finding, one surface
//--- over — and a popup in a corner reads as «the palette is broken».
int    DrawStripPlateX() { return s_dsOpen ? s_dsX : 0; }
int    DrawStripPlateY() { return s_dsOpen ? s_dsY : 0; }
int    DrawStripPlateW() { return s_dsOpen ? s_dsW : 0; }
//--- P-PAL-19e: is the strip still on screen? The bridge asks it so the palette
//--- CLOSES WITH ITS PARENT: a popup over a closed strip is a floater nobody owns,
//--- and it is exactly what «همراه والدش بسته بشه» is. Read here, asked once, in the
//--- only place that can see both sides.
bool   DrawStripPalParentLive() { return s_dsOpen && s_dsObj != ""; }
//--- and the flag the bridge spends: ONE frame, spent once, after the popup's route.
bool   DrawStripPalRepaintTake() { bool b = s_dsPalRepaint; s_dsPalRepaint = false; return b; }
int    DrawStripPalTargetSlot() { return s_dsPalSlot; }
bool   DrawStripPalTargetLive() { return (s_dsPalObj != "" && DrawStripIsColorSlot(s_dsPalSlot)); }
//--- the three the panels' State table asks, each ONE line and each the strip's own
//--- writer — so a pick lands on the drawing exactly the way a card row's own cell
//--- lands on its value, and every dependent (box marks, mid line, opacity) sees it.
color DrawStripPalTargetColor()
{
   if(!DrawStripPalTargetLive()) return clrNONE;
   //--- P-LVL-COLOR: a level target reads its own stored ink, never the slot's.
   if(s_dsPalLevel >= 0)
   {
      if(ObjectFind(0, s_dsPalObj) < 0) return clrNONE;
      if(s_dsPalLevel >= DrawLevelCount(s_dsPalObj)) return clrNONE;
      return (color)(int)ObjectGetInteger(0, s_dsPalObj, OBJPROP_LEVELCOLOR, s_dsPalLevel);
   }
   return DrawStripColorRead(s_dsPalObj, s_dsPalSlot);
}
int DrawStripPalTargetApply(const color c)
{
   if(!DrawStripPalTargetLive()) return 0;
   //--- P-LVL-COLOR: one stored level re-inks (undoable — the level set snapshot
   //--- carries per-level colors), the pen's children follow in the same frame.
   if(s_dsPalLevel >= 0)
   {
      if(ObjectFind(0, s_dsPalObj) < 0) return 0;
      if(s_dsPalLevel >= DrawLevelCount(s_dsPalObj)) return 0;
      if((int)c < 0) return 0;
      DrawStripUndoPush();
      ObjectSetInteger(0, s_dsPalObj, OBJPROP_LEVELCOLOR, s_dsPalLevel, c);
      FibPenSync(s_dsPalObj, false);
      DrawStripRecentPush(c);
      int gotL = (int)ObjectGetInteger(0, s_dsPalObj, OBJPROP_LEVELCOLOR, s_dsPalLevel);
      DrawStripDiagEmit("[drawstrip] PALAPPLY live=1 obj=\"" + s_dsPalObj + "\" slot=" +
                        IntegerToString(s_dsPalSlot) + " level=" + IntegerToString(s_dsPalLevel) +
                        " picked=" + DrawStripColorHex(c) +
                        " read=" + DrawStripColorHex((color)gotL));
      s_dsPalRepaint = true;
      return 1;
   }
   DrawStripColorCommit(s_dsPalSlot, c);
   DrawStripRecentPush(c);
   //--- P-PAL-19d (2026-10-02) — THE SECOND PICK IS A SEPARATE CASE, and the report
   //--- is «یک بار که یک رنگی رو انتخاب میکنم بقیه رنگ‌ها اعمال نمیشه». The MODEL
   //--- says the target is a static that outlives the pick, so the second click
   //--- should take the same three lines as the first — and the screen says it does
   //--- not. Nothing here is guessed: the line below is the WITNESS, through the
   //--- flushed channel (never `Print` — P-LOG-3), and it carries the three numbers
   //--- that decide the case: is the target still live, which slot, and what the
   //--- drawing READS BACK after the commit. `applied=` and `read=` disagreeing is
   //--- the commit; both 0 with `live=1` is the click that never arrived.
   int got = (int)DrawSlotRead(s_dsPalObj, s_dsPalSlot);   // double -> int, explicit (the project's own cast)
   DrawStripDiagEmit("[drawstrip] PALAPPLY live=" + IntegerToString((int)DrawStripPalTargetLive())
                    + " obj=\"" + s_dsPalObj + "\" slot=" + IntegerToString(s_dsPalSlot)
                    + " picked=" + DrawStripColorHex(c)
                    + " read=" + DrawStripColorHex((color)got));
   //--- P-PAL-19f (2026-10-02) — NO REPAINT FROM INSIDE THE POPUP'S OWN ROUTE. The
   //--- first bridge build called `DrawStripPaint()` here, and the report was
   //--- «یک رنگ انتخاب می‌کنم کل استریپ بسته می‌شه»: the strip repainted in the MIDDLE
   //--- of the palette's click, while the palette still owned the event, so the strip
   //--- rebuilt itself from a half-served gesture and the one who closed was the frame
   //--- it was not driving. The apply OWNS A FLAG; the BRIDGE spends it, once, after
   //--- the popup's route has returned — the same discipline the entry already uses
   //--- for «a user action settles the frame it owed, in the same event» (P-PERF-34).
   s_dsPalRepaint = true;
   return 1;
}
int DrawStripPalTargetAlpha()
{
   if(!DrawStripPalTargetLive()) return -1;
   //--- P-LVL-COLOR: one level has no tone of its own (-1 = no TR track).
   if(s_dsPalLevel >= 0) return -1;
   return DrawSlotAlphaGet(s_dsPalObj, s_dsPalSlot);
}
//--- P-DRAW-64a2 (2026-10-02) — WHICH SLOT, IN THE STRIP'S OWN WORDS. The popup's two
//--- role chips hold the KIND (`PAL_DRAW_BORDER` / `PAL_DRAW_FILL`, the panels' ladder);
//--- the SLOT is `DRAW_SLOT_COLOR` / `DRAW_SLOT_FILLCLR`, which is this module's
//--- vocabulary and nobody else's. So the chip asks here and the answer is a slot —
//--- the popup never translates a colour role into a slot index by arithmetic, which is
//--- how a border pick would end up writing the interior's tag.
void DrawStripPalRoleSet(const int role)
{
   if(s_dsPalObj == "" || s_dsPalSlot == DSTRIP_PICK_NONE) return;
   //--- P-DRAW-BODY-UI: a handle colour has no second role — the BORDER/FILL
   //--- chips must not retarget it onto the levels while the popup is open.
   if(s_dsPalSlot == DRAW_SLOT_BODYCOLOR) return;
   //--- P-LVL-COLOR: one level is one target — the role chips keep it.
   if(s_dsPalLevel >= 0) return;
   int want = (role == 0) ? DRAW_SLOT_COLOR : DRAW_SLOT_FILLCLR;
   if(!DrawSlotAvailable(DrawKindOf(s_dsPalObj), want)) return;
   s_dsPalSlot = want;
}
//--- P-PAL-20 — THE REPAINT IS A REQUEST THE BRIDGE SPENDS, and this is the ASK, so a
//--- caller outside the strip never calls `DrawStripPaint()` itself (that is a paint
//--- from inside somebody else's route — P-PAL-19f's own lesson). One flag, one spender.
void DrawStripPalRepaintAsk() { s_dsPalRepaint = true; }

// ═══════════════════════════════════════════════════════════════════════════
// P-PAL-20 (2026-10-02) — THE SURFACE LEDGER. THE DISMISSAL HAD NO NAME FOR THE POPUP.
//
// The report was «یک رنگ انتخاب می‌کنم کل استریپ بسته می‌شه», and the path is one line
// long. A colour pick is a release on TWO channels: `HandleUIChartEvent` serves the
// palette's swatch first (it runs before the strip in OnChartEvent), then the strip's
// router asks `DrawStripPointInside` about the release PIXEL — the pixel is on the
// popup, not on the strip — reads false, and calls `DrawStripClose()` (Router:1113).
// The colour did apply; the strip was eaten by the frame that did it.
//
// WHY IT IS A LEDGER AND NOT ONE MORE CLAUSE: `DrawStripPointInside` already grew one
// clause per popup — the gear panel (P-DRAW-32), the colour board (P-DRAW-48) — and the
// colour board is gone (P-PAL-19): its popup now lives in the panels, in a module the
// strip cannot see and must not know. So the clause list did not get long, it got
// WRONG, and the next popup would have broken it the same way. The strip's real rule
// was never «the plate and two special cases»: it is «a pixel on ANY surface the strip
// owns is not a click on the chart». One registry answers that, it grows without a
// branch, and it is fed by the ONE place that can see both sides (the entry's bridge).
//
// The entries are republished WHOLE every event by that single writer, so the ledger
// can never hold a rectangle of a popup that is already gone — the failure mode of a
// list written once and patched at each open.
// ═══════════════════════════════════════════════════════════════════════════
#define DSTRIP_SURF_MAX 4                 // two popups today; four is the ceiling, not a plan
static int s_dsSurfN = 0;
static int s_dsSurfX[DSTRIP_SURF_MAX], s_dsSurfY[DSTRIP_SURF_MAX];
static int s_dsSurfW[DSTRIP_SURF_MAX], s_dsSurfH[DSTRIP_SURF_MAX];

//--- the one writer's reset: called by the bridge on EVERY event, before it republishes.
void DrawStripSurfaceClear() { s_dsSurfN = 0; }
//--- append one owned surface. A zero-sized rect is not a surface (P-DRAW-32's own
//--- `s_dsGearW0 > 0` test): publishing a collapsed popup would claim nothing and
//--- would still cost the ledger a slot.
void DrawStripSurfacePublish(const int x, const int y, const int w, const int h)
{
   if(s_dsSurfN >= DSTRIP_SURF_MAX) return;
   if(w <= 0 || h <= 0) return;
   s_dsSurfX[s_dsSurfN] = x; s_dsSurfY[s_dsSurfN] = y;
   s_dsSurfW[s_dsSurfN] = w; s_dsSurfH[s_dsSurfN] = h;
   s_dsSurfN++;
}
bool DrawStripSurfaceAt(const int mx, const int my)
{
   int m = DSTRIP_SKIN_M + 2;   // the skin's fringe is plate, not chart (P-DRAW-29)
   for(int i = 0; i < s_dsSurfN; i++)
      if(mx >= s_dsSurfX[i] - m && mx <= s_dsSurfX[i] + s_dsSurfW[i] + m &&
         my >= s_dsSurfY[i] - m && my <= s_dsSurfY[i] + s_dsSurfH[i] + m) return true;
   return false;
}

void DrawStripPublishRect()
{
   if(!s_dsOpen || s_dsW <= 0 || s_dsH <= 0)
   {
      g_UIStripRX = -1; g_UIStripRY = -1; g_UIStripRW = 0; g_UIStripRH = 0;
      return;
   }
   int x1 = s_dsX - DSTRIP_SKIN_M;
   int y1 = s_dsY - DSTRIP_SKIN_M;
   int x2 = s_dsX + s_dsW + DSTRIP_SKIN_M;
   int y2 = s_dsY + s_dsH + DSTRIP_SKIN_M;
   if(s_dsGear != 0 && s_dsGearW0 > 0 && s_dsGearH > 0)
   {
      if(s_dsGEX - DSTRIP_SKIN_M < x1) x1 = s_dsGEX - DSTRIP_SKIN_M;
      if(s_dsGEY - DSTRIP_SKIN_M < y1) y1 = s_dsGEY - DSTRIP_SKIN_M;
      if(s_dsGEX + s_dsGearW0 + DSTRIP_SKIN_M > x2) x2 = s_dsGEX + s_dsGearW0 + DSTRIP_SKIN_M;
      if(s_dsGEY + s_dsGearH + DSTRIP_SKIN_M > y2) y2 = s_dsGEY + s_dsGearH + DSTRIP_SKIN_M;
   }
   //--- P-DRAW-48: the COLOUR BOARD is occupancy too — a card placed by the
   //--- neighbours must clear it, and a fresh board must clear them.
   if(DrawStripIsColorSlot(s_dsPicker) && s_dsBW > 0 && s_dsBH > 0)
   {
      if(s_dsBX - DSTRIP_SKIN_M < x1) x1 = s_dsBX - DSTRIP_SKIN_M;
      if(s_dsBY - DSTRIP_SKIN_M < y1) y1 = s_dsBY - DSTRIP_SKIN_M;
      if(s_dsBX + s_dsBW + DSTRIP_SKIN_M > x2) x2 = s_dsBX + s_dsBW + DSTRIP_SKIN_M;
      if(s_dsBY + s_dsBH + DSTRIP_SKIN_M > y2) y2 = s_dsBY + s_dsBH + DSTRIP_SKIN_M;
   }
   g_UIStripRX = x1;
   g_UIStripRY = y1;
   g_UIStripRW = x2 - x1;
   g_UIStripRH = y2 - y1;
}
//--- P-UI-113c (2026-09-23): THE OPENING PRESS'S OWN CLICK-FAMILY WINDOW. The hold
//--- fires while the button is STILL DOWN, so the release that ends it lands on the
//--- drawing = outside the strip, and the TV-style dismissal would close what the
//--- hold just opened («چرا با رها کردن هولد استریپ هم بسته میشه»). A one-shot flag
//--- cannot fix it: ONE release is reported on more than one channel (the chart's
//--- own CHARTEVENT_CLICK and the object's OBJECT_CLICK), so a shot spends the
//--- first while the second dismisses the strip the user was just shown. So it is a
//--- WINDOW, re-armed by the press's own witnesses: ARM at the fire for the
//--- press's whole life, the MOVE STREAM's release witness shortens it to the
//--- twin-event tail, a new press edge (or a close) ends it.
#define DSTRIP_OPEN_TAIL_MS      800     // twin-event tail after the release witness
#define DSTRIP_OPEN_PRESS_MAX_MS 10000   // the longest a press may claim its own clicks
static uint s_dsOpenerUntil = 0;         // 0 = disarmed; else the press's own deadline
static uint s_dsOpenerTailUntil = 0;     // the twin-event tail (after the release witness)
static int  s_dsOpenerN = 0;             // twin events left to spend (one release = two channels)
void DrawStripOpenerArm()    { s_dsOpenerUntil = GetTickCount() + DSTRIP_OPEN_PRESS_MAX_MS; s_dsOpenerTailUntil = 0; s_dsOpenerN = 2; }
void DrawStripOpenerDisarm() { s_dsOpenerUntil = 0; s_dsOpenerTailUntil = 0; s_dsOpenerN = 0; }
//--- P-UI-155 (2026-10-08) — THE FALLBACK'S OWN TWIN FLAG. A chart-first open
//--- (hollow interior) may be followed by the same release's object channel;
//--- that twin must be spent, never closed. Time-bounded (twin channels arrive
//--- milliseconds apart), never token-counted: a stale token budget ate genuine
//--- clicks for ten seconds. Armed only by the fallback open below; the spent
//--- check clears it, and the deadline clears itself.
static bool s_dsTwinOwed = false;
static uint s_dsTwinUntil = 0;
void DrawStripTwinArm() { s_dsTwinOwed = true; s_dsTwinUntil = GetTickCount() + DSTRIP_OPEN_TAIL_MS; }
bool DrawStripTwinSpent()
{
   if(!s_dsTwinOwed || !TickDeadlinePending(s_dsTwinUntil)) { s_dsTwinOwed = false; return false; }
   s_dsTwinOwed = false;
   return true;
}
bool DrawStripOpenerClickSpent()
{
   if(!TickDeadlinePending(s_dsOpenerUntil) && !TickDeadlinePending(s_dsOpenerTailUntil)) { s_dsOpenerN = 0; return false; }
   if(s_dsOpenerN <= 0) return false;
   s_dsOpenerN--;
   return true;
}
//--- P-UI-113g (2026-09-24): SELECTION IS REPAIRED AFTER MT4'S CLICK, NOT INSIDE
//--- THE CLICK CALLBACK. P-UI-113f selected the hold target both at the fire and
//--- on the release event, but MT4 commits the terminal's own press/release
//--- selection state after this callback returns. Its last step therefore cleared
//--- the eight handles/context toolbar that the release had just restored. The
//--- repair belongs to the already-running tick/timer pump: one bounded wait past
//--- the event, guarded writes only, and a new press or a close cancels it so the
//--- user's next gesture always wins.
//--- The name is explicit because a same-object CHART_CHANGE/OBJECT_DRAG ride
//--- rebuilds the strip through DrawStripClose; OpenAt snapshots and restores this
//--- repair exactly as it restores the opening-press window.
#define DSTRIP_SELECT_REPAIR_DELAY_MS 120   // let MT4 finish the release callback first
#define DSTRIP_SELECT_REPAIR_TTL_MS   1800  // bounded proof window, not a selection lock
static string s_dsSelectRepairName = "";
static uint   s_dsSelectRepairAt = 0;      // first post-event repair is legal here
static uint   s_dsSelectRepairUntil = 0;   // 0 = no repair pending
void DrawStripHoldSelectionDisarm()
{
   s_dsSelectRepairName = "";
   s_dsSelectRepairAt = 0;
   s_dsSelectRepairUntil = 0;
}
//--- P-DRAW-17: the left button's press latch, and the ONE owner of the press
//--- edge fact (`s_dsLeftPress`). The trigger needs it (a click, not a drag) and
//--- the grip carry needs it (start a carry on the press) - so the edge is
//--- computed ONCE, in the router head, which runs on EVERY move whether the
//--- strip is open or not. Two owners of "the button just went down" is how the
//--- carry and the trigger would drift apart.
//--- P-UI-113b (2026-09-23): and the head STORES it (`s_dsLeftPrev = tleft`) -
//--- without that one line the "edge" is just the button state, re-read as a
//--- fresh press by every move of a held hand (see the head's own note). The
//--- button-up channels resync it, so an off-window release cannot stick it DOWN.
static bool     s_dsLeftPrev = false;
static bool     s_dsLeftPress = false;   // true on the move that carried the press edge
static int      s_dsPressX = 0, s_dsPressY = 0;
static string   s_dsPressObj = "";       // P-UI-113i: the drawing named by that press
static int      s_dsTravel = 0;          // furthest the LEFT hand got while held
static bool     s_dsPressTracked = false;   // P-UI-113d: a press EDGE was seen for this
                                             // cycle, so `s_dsTravel` is this gesture's
                                             // (a zero-move press leaves no edge: the
                                             // release then reads as a click, never a drag)
static uint     s_dsPressEdgeMs = 0;         // P-UI-155: when that edge ran (0 = none yet).
                                             // A travel veto without a fresh edge is a
                                             // PREVIOUS gesture's travel against a still
                                             // press — it may only refuse, never allow.
//--- P-UI-113j (2026-09-25) — THE PRESS NAMES ITS OWN DRAWING. `s_dsPressObj`
//--- above exists only when the MOVE STREAM carried the press edge: a still press
//--- carries none (P-LM-13). The release then fell back to a live hit test, and
//--- MT4's selected controls are terminal UI - their handles are accepted only
//--- while the object IS selected (P-UI-113h), which the terminal clears around
//--- its own click. Reported: hold a SELECTED drawing, the strip opens, and the
//--- release closes it - while the same gesture works on an unselected one.
//--- So the latch - which hit-tests the press pixel anyway - KEEPS its answer for
//--- the whole press cycle: one hit test per press (P-DRAW-04), selection-free.
static bool     s_dsPressCycle = false;  // the latch named THIS press cycle
static string   s_dsPressCycleObj = "";  // the drawing its press pixel landed on ("" = chart)
static uint     s_dsPressCycleMs = 0;    // the cycle's life bound: the press cap below
//--- P-UI-130 (2026-10-02) — THE CYCLE'S LIFE IS THE PRESS'S, NOT THE OPENER'S.
//--- P-UI-115 armed this cycle and left its life bound at `DSTRIP_OPEN_PRESS_MAX_MS`
//--- — the OPENER WINDOW's own budget, ten seconds — and the live chart says what
//--- a ten-second refusal window costs. One latch on a box the hand was about to
//--- DRAG walked out from under the finger, the drag's release never arrived on
//--- the click channel, and the cycle went on to refuse FIVE real presses in a row
//--- (EURUSD,M1 00:12:57.036 latch -> :57.473 refused -> :57.931, :58.451,
//--- :58.939, 00:13:00.370, 00:13:01.481 all refused -> the user gave up until
//--- 00:14:41). That is «هولد بعضی وقتها باز نمیشه» exactly, and no line of the
//--- log named the owner until DIAG-116 printed `press refused: cycle live`.
//--- The cycle has ONE job — keep a FLAP from re-timing a press it already named
//--- (P-UI-115c) — and the flaps it was measured against are milliseconds apart
//--- (179/252/488 ms). 2 s covers every press that can still matter and can never
//--- outlive its press far enough to eat the next one (every release ends it).
//--- A gesture already IN MOTION is guarded by its own witness instead: the
//--- router's drag heartbeat (P-UI-130 in DrawStrip_Router.mqh).
#define DSTRIP_PRESS_CYCLE_MS 2000
void DrawStripPressCycleSet(const string nm)
{ s_dsPressCycle = true; s_dsPressCycleObj = nm; s_dsPressCycleMs = GetTickCount() + DSTRIP_PRESS_CYCLE_MS; }
void DrawStripPressCycleClear() { s_dsPressCycle = false; s_dsPressCycleObj = ""; s_dsPressCycleMs = 0; }
bool DrawStripPressCycleLive()
{ return (s_dsPressCycle && TickDeadlinePending(s_dsPressCycleMs)); }
//--- P-UI-114 (2026-09-23) — dead right-click era deleted (user order:
//--- extra code out, compile back down). The strip opens on a LEFT hold now.

//--- P-DRAW-13: single-step undo — the pre-mutation looks of the group (names +
//--- packed slots), the held drawing's level set, and a duplicate's copy name.
//--- Trash is not undoable (MT4 has no undelete); undo covers looks only.
static bool     s_duValid = false;
static int      s_duN = 0;
static string   s_duName[DSTRIP_UNDO_MAX];
static color    s_duClr[DSTRIP_UNDO_MAX];
static int      s_duW[DSTRIP_UNDO_MAX], s_duSt[DSTRIP_UNDO_MAX];
static int      s_duFill[DSTRIP_UNDO_MAX], s_duRay[DSTRIP_UNDO_MAX];
static color    s_duFillClr[DSTRIP_UNDO_MAX];    // P-DRAW-64: the interior's colour
static int      s_duFillOp[DSTRIP_UNDO_MAX];     // and its own tone
static int      s_duFont[DSTRIP_UNDO_MAX], s_duGlyph[DSTRIP_UNDO_MAX], s_duBack[DSTRIP_UNDO_MAX];
static color    s_duBodyClr[DSTRIP_UNDO_MAX];   // P-DRAW-BODY-UI: undo restores the handle too
static int      s_duBodyW[DSTRIP_UNDO_MAX], s_duBodySt[DSTRIP_UNDO_MAX];
static int      s_duLvN = 0;
static double   s_duLvV[DSTRIP_UNDO_LV];
static color    s_duLvC[DSTRIP_UNDO_LV];
static int      s_duLvW[DSTRIP_UNDO_LV], s_duLvS[DSTRIP_UNDO_LV];
static string   s_duLvT[DSTRIP_UNDO_LV];   // P-LVL-TEXT: one level's own note
//--- P-LVL-TEXT (2026-10-04) — ONE LEVEL'S NOTE, ARMED. The label zone of a level
//--- row arms the e4 field on that STORED level; Enter commits LEVELTEXT.
//--- Disarmed by the commit and by GearClose (strip close rides it).
static bool     s_dsLvlDescArmed = false;
static string   s_dsLvlDescObj = "";
static int      s_dsLvlDescIdx = -1;
bool DrawStripLvlDescWant()
{
   if(!s_dsLvlDescArmed || s_dsLvlDescObj == "" || s_dsLvlDescObj != s_dsObj) return false;
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   if(s_dsLvlDescIdx < 0 || s_dsLvlDescIdx >= DrawLevelCount(s_dsObj)) return false;
   return true;
}
static string   s_duCopy = "";

string DrawStripObjName(const int i)  { return "PnlDrawS_" + IntegerToString(i); }
string DrawStripIconName(const int i) { return "PnlDrawS_" + IntegerToString(i) + "I"; }
//--- the shell chrome: grip (drag), badge (kind xN, info only), actions.
string DrawStripGripName() { return "PnlDrawS_H"; }
string DrawStripGripIconName() { return "PnlDrawS_HI"; }
string DrawStripBadgeName() { return "PnlDrawS_B"; }
string DrawStripActName(const int a) { return "PnlDrawS_A" + IntegerToString(a); }
string DrawStripActIconName(const int a) { return "PnlDrawS_A" + IntegerToString(a) + "I"; }
//--- the popover's rows (P = button, PI = icon face, PT = left-aligned label).
string DrawStripPickName(const int r) { return "PnlDrawS_P" + IntegerToString(r); }
string DrawStripPickIconName(const int r) { return "PnlDrawS_P" + IntegerToString(r) + "I"; }
string DrawStripPickLabelName(const int r) { return "PnlDrawS_P" + IntegerToString(r) + "T"; }
string DrawStripPickChipName(const int r) { return DrawStripPickIconName(r) + "C"; }
string DrawStripPickRailName(const int r) { return DrawStripPickName(r) + "R"; }
//--- P-DRAW-33: the colour surfaces' glass sheen — one face per colour cell, so a
//--- tap on the sheen is a tap on the cell (the `+ "C"` chip pattern, one letter up).
string DrawStripPickGlassName(const int r) { return DrawStripPickName(r) + "G"; }
string DrawStripGridGlassName(const int g) { return DrawStripGridName(g) + "G"; }
//--- TV parity board (2026-09-26): the popover's own chrome — grip seat, the
//--- RECENT band's own cells (the grid is the user's 64 only) and the HEX field.
string DrawStripPHeadGName() { return "PnlDrawS_PHeadG"; }
string DrawStripPHeadGChipName() { return "PnlDrawS_PHeadGC"; }
string DrawStripPHeadGIconName() { return "PnlDrawS_PHeadGI"; }
//--- P-DRAW-92 (2026-09-30) — THE BOARD'S PAGE SEATS, NAMED LIKE EVERY OTHER
//--- BOARD OBJECT. They were spelled inline in the paint (`"PnlDrawS_Page" +
//--- IntegerToString(k)`) — P-PAL-21: the board's chrome prune went with the board.
//--- the board's chrome down (DrawStrip_GearA.mqh) — never listed them: close the
//--- board, or switch a colour slot to a width/style list, and the two `<` `>` seats
//--- and the "1/2" caption stayed floating over the strip. Found by
//--- `node tools/object_lifecycle_check.js` once its helper table went tree-wide:
//--- `DrawStripBtn paints PnlDrawS_Page…"PnlDrawS_Page" — no destroy path`.
string DrawStripPageSeatName(const int k)  { return "PnlDrawS_Page" + IntegerToString(k); }
string DrawStripPageLabelName()            { return "PnlDrawS_PageT"; }
string DrawStripPRecName(const int i) { return "PnlDrawS_PR" + IntegerToString(i); }
string DrawStripPRecGlassName(const int i) { return DrawStripPRecName(i) + "G"; }
string DrawStripPRecLabelName() { return "PnlDrawS_PRecT"; }
//--- P-PAL-14: the well an EMPTY recent slot wears. A seat of its own, because the
//--- slot is a state the trader can see, not an absence.
string DrawStripPRecEmptyName(const int i) { return DrawStripPRecName(i) + "E"; }
string DrawStripPHexLbName() { return "PnlDrawS_PHexLb"; }
string DrawStripPHexEdName() { return "PnlDrawS_PHexEd"; }
//--- P-DRAW-48: the OPACITY band's own five objects (Lb = its label, T = the bed,
//--- F = the filled part, K = the knob, V = the `NN%` readout).
string DrawStripPOpLbName()    { return "PnlDrawS_POpLb"; }
string DrawStripPOpBedName()   { return "PnlDrawS_POpT"; }
string DrawStripPOpFillName()  { return "PnlDrawS_POpF"; }
string DrawStripPOpKnobName()  { return "PnlDrawS_POpK"; }
string DrawStripPOpValName()   { return "PnlDrawS_POpV"; }
//--- the gear panel: tabs (GT), grid cells (GG/GGI), list rows (GR/GRI/GRT),
//--- foot (GF), edits (GE).
string DrawStripGridName(const int g) { return "PnlDrawS_GG" + IntegerToString(g); }
string DrawStripGridIconName(const int g) { return "PnlDrawS_GG" + IntegerToString(g) + "I"; }
string DrawStripRowName(const int r) { return "PnlDrawS_GR" + IntegerToString(r); }
string DrawStripRowIconName(const int r) { return "PnlDrawS_GR" + IntegerToString(r) + "I"; }
string DrawStripRowLabelName(const int r) { return "PnlDrawS_GR" + IntegerToString(r) + "T"; }
string DrawStripRowChipName(const int r) { return DrawStripRowIconName(r) + "C"; }
string DrawStripRowRailName(const int r) { return DrawStripRowName(r) + "R"; }
string DrawStripRowStateName(const int r) { return DrawStripRowName(r) + "S"; }
string DrawStripRowSepName(const int r) { return DrawStripRowName(r) + "L"; }
//--- P-DRAW-117: the group row's VALUE DIGEST — a member of the row family (the
//--- row's own `D`), because it is drawn in the row's own cell and dies with it.
string DrawStripRowDigestName(const int r) { return DrawStripRowName(r) + "D"; }
string DrawStripFootName(const int f) { return "PnlDrawS_GF" + IntegerToString(f); }
string DrawStripFootSkinName(const int f) { return DrawStripFootName(f) + "B"; }
string DrawStripFootGlyphName(const int f) { return DrawStripFootName(f) + "G"; }
string DrawStripFootLabelName(const int f) { return DrawStripFootName(f) + "T"; }
string DrawStripEditName(const int e) { return "PnlDrawS_GE" + IntegerToString(e); }
string DrawStripBgName() { return "PnlDrawS_BG"; }
string DrawStripBoardBgName() { return "PnlDrawS_BBG"; }   // P-DRAW-48: the board's own plate bg
//--- P-DRAW-32: the SETTINGS PANEL's own plate — its own family, so the two
//--- surfaces paint, purge and answer a tap apart (`DrawStripIsBg` matches both).
string DrawStripGearBgName() { return "PnlDrawS_GBG"; }
//--- P-DRAW-117 (2026-10-01) — `DrawStripGearTabName` / `DrawStripGearTabLineName`
//--- / `DrawStripGearTrackName` are RETIRED with the tab row. The panel's nav is a
//--- column of group ROWS now, so it rides the row family (`DrawStripRowName`) and
//--- the three retired spellings survive only where they must: as the ORPHAN SWEEP
//--- in `DrawStripGearObjectsPurge` (a chart painted by the tab build), which deletes
//--- them by literal name (GearA). Naming a retired object from a helper here would be
//--- a name no paint can produce and no reader can need.
string DrawStripGearHeadName(const string s) { return "PnlDrawS_GH" + s; }
string DrawStripGearSectionName(const int i) { return "PnlDrawS_GS" + IntegerToString(i); }
string DrawStripGearSectionLineName(const int i) { return DrawStripGearSectionName(i) + "L"; }
//--- P-DRAW-125 (2026-10-01) — "CREATE OR REWRITE?" MUST ASK THE TYPE, NOT THE NAME.
//--- Every writer decided that question from `ObjectFind(0, nm) < 0` alone, and the
//--- tree's own record names the consequence (DrawStripSweepStale, GearA): "a name
//--- that is already there IS reused — with whatever TYPE the older build created it,
//--- and MT4 draws a button's text onto a bitmap label by writing properties nobody
//--- reads: an object that exists, answers ObjectFind, and paints NOTHING." The
//--- prefix wipe at attach cannot reach a name a MID-SESSION path left mis-typed (a
//--- cell that changed role, a family half rebuilt, an orphan of the retired tab
//--- build), so the reader lives here, where every writer can reach it: the object's
//--- OWN type against the type the painter needs. A foreign name is dropped, and the
//--- writer's own create — kept IN the writer, so the lifecycle gate still sees the
//--- birth and the layer write in one block — rebuilds it. Bounded: one extra type
//--- read per object per paint, and a reclaim happens at most once per name.
void DrawStripForeign(const string nm, const int type)
{
   if(ObjectFind(0, nm) < 0) return;
   if((int)ObjectGetInteger(0, nm, OBJPROP_TYPE) == type) return;
   static bool saidType = false;
   if(!saidType)
   {
      saidType = true;
      Print("[drawstrip] object of another type reclaimed obj=", nm,
            " type=", (int)ObjectGetInteger(0, nm, OBJPROP_TYPE), " want=", type);
   }
   ObjectDelete(0, nm);
}
string DrawStripGearCloseName() { return DrawStripGearHeadName("X"); }
string DrawStripGearCloseSkinName() { return DrawStripGearCloseName() + "B"; }
string DrawStripGearCloseIconName() { return DrawStripGearCloseName() + "I"; }
int    DrawStripGearX() { return s_dsGEX; }   // P-DRAW-32: the panel's own origin
//--- P-DRAW-73: `DrawStripGearCW()` is retired here — 1 hit in the tree (its own
//--- definition) since birth, and the head painter's write to `s_dsGearW` made it
//--- answer 312 where the layout means 280. The paint asks `DSTRIP_GEAR_W - 2*PAD`
//--- (narrow) or `s_dsGearW0 - 2*PAD` (the plate) directly, one line each.
//--- P-DRAW-19 (2026-09-24) — DOES THE CARRY OWN THE VIEW?
//--- The grip carry takes the project's ONE view lock (P-UI-113d:
//--- `ChartViewLockAcquire` at the press edge, `ChartViewLockAssert` on every held
//--- step, `DrawStripGripRelease` at every end). The 250 ms watchdog that rebuilds
//--- that lock from OWNERSHIP intent (`ChartScrollReconcile` -> `ChartLockIntended`,
//--- BiotakPanels.mqh - included AFTER this module, so this accessor is DEFINED
//--- before its ONE reader) must be able to NAME it: without the term the reconcile
//--- reads the carry's lock as a LEAK, hard-releases it inside the first 250 ms of
//--- the gesture and hands the scroll back under the hand - the report this answers
//--- («هنوز هنگام درگ چارت پشتش قفل نمیشه»). P-LM-11/P-BK-62's law, worn here
//--- unchanged: a gesture that takes the view lock names itself in that list the day
//--- it is born. ONE reader, so the answer cannot drift from the lock it explains.
//--- P-DRAW-32: the SETTINGS PANEL's carry takes it too (its header bar is its
//--- handle), so BOTH latches are named here — one reader, two owners. P-DRAW-48:
//--- the OPACITY BAR's own drag, the fourth, added the day it was born (A-09/G-07).
bool   DrawStripViewOwned() { return (s_dsGripLive || s_dsGGripLive || s_dsBGripLive || s_dsOpGrab || s_dsPalGrab); }
//--- P-DRAW-09b: how many drawings this strip is editing (1 = the held one).

//--- P-DRAW-08c: is this point ON the strip? Two gaps came from not asking:
//---   * a button tap also arrives as a chart CLICK on some builds, and the
//---     dismissal branch below ate the strip in the same event that used it;
//---   * a press that lands on the strip must never be read as a press on the
//---     drawing underneath it (the hold's own hit test starts with this).
//--- The size is the one the OPEN measured (`s_dsW`/`s_dsH`), never re-derived
//--- here: this question is asked on the press edge, where a kind lookup would be
//--- work for an answer already in hand.
bool DrawStripPointInside(const int mx, const int my)
{
   if(!s_dsOpen) return false;
   //--- P-DRAW-29: the skin stands DSTRIP_SKIN_M past the content on every
   //--- side — its fringe is plate, not chart.
   int m = DSTRIP_SKIN_M + 2;
   if(s_dsW > 0 && s_dsH > 0 &&
      mx >= s_dsX - m && mx <= s_dsX + s_dsW + m &&
      my >= s_dsY - m && my <= s_dsY + s_dsH + m) return true;
   //--- P-DRAW-32: the SETTINGS PANEL is our surface too. A tap on its plate is
   //--- not a tap on the chart, so it must never dismiss the strip that owns it
   //--- (the panel is where the user was just working).
   if(s_dsGear != 0 && s_dsGearW0 > 0 && s_dsGearH > 0 &&
      mx >= s_dsGEX - m && mx <= s_dsGEX + s_dsGearW0 + m &&
      my >= s_dsGEY - m && my <= s_dsGEY + s_dsGearH + m) return true;
   //--- P-DRAW-48: the COLOUR BOARD is our surface too — it can float anywhere,
   //--- including over the chart, and a click on its plate is not a click on the
   //--- chart (it would dismiss the very strip the board belongs to).
   if(DrawStripIsColorSlot(s_dsPicker) && s_dsBW > 0 && s_dsBH > 0 &&
      mx >= s_dsBX - m && mx <= s_dsBX + s_dsBW + m &&
      my >= s_dsBY - m && my <= s_dsBY + s_dsBH + m) return true;
   //--- P-PAL-20: AND WHATEVER ELSE THIS STRIP OWNS — the popups the entry's bridge
   //--- republished this event (the cards' palette, opened by a colour cell). Same
   //--- law as the two clauses above, one registry instead of one branch per popup.
   if(DrawStripSurfaceAt(mx, my)) return true;
   return false;
}

// ═══════════════════════════════════════════════════════════════════════════
// P-DRAW-84 (2026-09-29) — THE PANEL'S BUTTONS ARE DEAD, AND THE REASON IS ONE
// FLAG, NOT TWELVE BUGS.
//
// Every painter in this file is born `OBJPROP_SELECTABLE = false`
// (DrawStripBtnZ:3317, DrawStripFaceZ:3366, DrawStripLblAt:3413,
// DrawStripRect:3444), and that is CORRECT for this project: the indicator owns
// all input, and the strip opens by a coordinate hit test (DrawStripOpenAt),
// not by a click on an object. But the gear panel's ROUTER is a NAME router:
// every branch of the CHARTEVENT_OBJECT_CLICK chain at 7408-7433 compares
// `sparam` against a control's own object name — DrawStripRowName(r),
// DrawStripFootName(f), the retired DrawStripGearTabName(t), and so on. MT4 never emits
// OBJECT_CLICK for a non-selectable object, so `sparam` can never BE one of
// those names: every tab, row, switch, grid chip and foot button was dead on a
// green compile. The cards work because BiotakPanels has P-UI-74's
// `PnlClickFallback(mouseX, mouseY)` — the COORDINATE channel gets first
// refusal, the name router only runs when no control acted. The panel had no
// such channel at all.
//
// This function IS that channel for the gear panel, and it is deliberately
// written to read the SAME seat arrays the paint writes (`s_dsGRY/Col`,
// `s_dsGGX/Y/W/H`, `s_dsGearFootY`, `s_dsGearEditX/W/Y`,
// `s_dsGEY`, `s_dsGEX`, `s_dsGearW0`) — never a re-derived number. A hit test
// with its own arithmetic is a second grid, which is P-DRAW-77's defect again.
//--- P-DRAW-117: and the group headers ride those same row arrays now — the tab
//--- row's own band and `s_dsGearTabX/W` seats are retired with it.
//
// Order is Z-order, topmost first, because the panel's controls overlap: the
// head's X sits over the plate, the tab underline over its tab, the grid chips
// over their row. Returns true when a control acted (the caller spends the
// event); false when the point is dead space, so the name router below can
// still have it.
// ═══════════════════════════════════════════════════════════════════════════
bool DrawStripGearHit(const int mx, const int my)
{
   if(!s_dsOpen || s_dsObj == "") return false;
   if(s_dsGear == 0 || s_dsGearW0 <= 0 || s_dsGearH <= 0) return false;
   if(mx < s_dsGEX || mx > s_dsGEX + s_dsGearW0) return false;
   if(my < s_dsGEY || my > s_dsGEY + s_dsGearH) return false;

   int gx = s_dsGEX, gy = s_dsGEY;
   int colW = DrawStripGearColW();
   int px = gx + DSTRIP_GEAR_PAD;

   // --- the head's own X, and the grip that carries the panel. Both live in the
   // head band, which is above everything below, so they are asked first. The X's
   // seat is the paint's own: `closeX = gx + W0 - PAD - 26`, at `hy + 17`, 26x26
   // (3913-3914) — the 26 is the cards' own XBTN and is written there twice, so it
   // is read here from the same expression rather than a third literal.
   //--- P-DRAW-103: AND THE HIT IS THE PAINTED SHAPE. This tested a CIRCLE of radius
   //--- `26/2 + 3` = 16 against a painted 26x26 SQUARE, so the square's own four
   //--- corners were dead: at the diagonal the circle ends 11.3px from the centre
   //--- while the corner sits 18.4px out, leaving a 3.7px dead triangle at each
   //--- corner of the one control that closes the panel. A thumb pad of 3px on every
   //--- side keeps the seam with the grip (P-DRAW-36 stops the carry 16px short of
   //--- the corner) untouched: the box now runs `cx0-3 .. cx0+29` and the carry ends
   //--- at `cx0-16`, so the 13px gap the design asked for is still there and the
   //--- circle's slack is spent on the corners that were missing.
   if(s_dsGearHeadY >= 0)
   {
      int hy = gy + s_dsGearHeadY;
      if(my >= hy && my < hy + DSTRIP_GEAR_HEAD_H)
      {
         const int xbtn = 26, xpad = 3;
         int cx0 = gx + s_dsGearW0 - DSTRIP_GEAR_PAD - xbtn;
         int cy0 = hy + 17;
         if(mx >= cx0 - xpad && mx < cx0 + xbtn + xpad &&
            my >= cy0 - xpad && my < cy0 + xbtn + xpad)
         { DrawStripGearClose(); return true; }
      }
      //--- P-DRAW-85: the head is ALSO the panel's carry. Outside the X, a press
      //--- on it drags the panel (DrawStripGearGripAt owns the exact seat); the
      //--- user could not move the panel at all before this.
      if(DrawStripGearGripAt(mx, my)) return false;   // the grip's own handler acts
   }

   // --- P-DRAW-117: THE GROUP HEADERS ARE NOT ASKED HERE. A group is a ROW now
   // (`DSTRIP_GRK_GROUP` in `s_dsGRKind`), so it answers through the row probe below
   // — the same seat array the paint writes, which is P-DRAW-84's own law: one hit
   // test, no second grid. The retired tab band's probe (a `ty` band over `s_dsGearTabsY`
   // and the `s_dsGearTabX/W` seats) went with the tab row it measured.

   // --- the hex / text fields: a press takes focus for typing, no action
   // (P-DRAW-48). The seat is the SAME `s_dsGearEditX/W/Y` the paint wrote.
   //--- P-DRAW-94 (2026-09-30): AND THE SAME COLUMN. `s_dsGearEditCol[e]` is what
   //--- the WIDE pass writes when it moves a field into the right column
   //--- (DrawStripGearShiftItems, GearA:474) and the paint adds the same
   //--- `* DSTRIP_GEAR_COL` (GearB:1009). This probe was the ONE reader that did
   //--- not: on a wide tab (a fibo's Levels, 10+ rows) the "add a level" field was
   //--- DRAWN at px + 312 + editX and probed at px + editX — so the field could not
   //--- be focused by clicking it, and a click in the empty left column at that row
   //--- focused a field 312px away. One term, read from the paint's own expression.
   //--- P-DRAW-98: AND THE PAINT'S OWN WIDTH, INCLUDING ITS FALLBACK. This probe
   //--- skipped a field whose `s_dsGearEditW` is 0, and the paint does not skip it:
   //--- `int ew = (s_dsGearEditW[e] > 0) ? s_dsGearEditW[e] : cw` (GearB) gives it
   //--- the WHOLE cell. Only the two Paint-tab hex fields ever set a width, so the
   //--- `add a level` (e1), the `Caption` (e2) and the `Template name` (e3) fields
   //--- were drawn as full-width text boxes that no click could ever reach — and
   //--- every painter here is `OBJPROP_SELECTABLE=false`, so the terminal could not
   //--- reach them either. On the two tabs the gate measures narrow (Look 312, Text
   //--- 312) that is every field but the two hex ones. The guard is now the paint's
   //--- own `s_dsGearEditY[e] >= 0` (which is exactly the paint's `want`), and the
   //--- width is the paint's own expression, term for term.
   for(int e = 0; e < 5; e++)
   {
      if(s_dsGearEditY[e] < 0) continue;
      int ew = (s_dsGearEditW[e] > 0) ? s_dsGearEditW[e] : DrawStripGearCellW();
      if(ew <= 0) continue;
      int ex = px + s_dsGearEditCol[e] * DSTRIP_GEAR_COL + s_dsGearEditX[e];
      int ey = gy + s_dsGearEditY[e] + (DSTRIP_GEAR_ROW_H - DSTRIP_GEAR_EDIT_H) / 2;
      if(mx >= ex && mx < ex + ew &&
         my >= ey && my < ey + DSTRIP_GEAR_EDIT_H)
      {
         if(ObjectFind(0, DrawStripEditName(e)) >= 0)
            ObjectSetInteger(0, DrawStripEditName(e), OBJPROP_STATE, true);
         //--- P-DRAW-118 (2026-10-01): the panel's two COLOUR fields (e0/e4) are gone
         //--- with their hex boxes, so no field here arms `s_dsHexFocus` any more —
         //--- that guard belongs to the BOARD's HEX field alone now (the router arms
         //--- it on the board's own name and `DrawStripPopHexEnd` releases it).
         return true;
      }
   }

   // --- the grid chips (Style tab's width / style / ray rows).
   for(int g = 0; g < s_dsGGN && g < DSTRIP_GRID_MAX; g++)
   {
      if(s_dsGGH[g] <= 0) continue;
      int cx = gx + s_dsGGX[g];
      int cy = gy + s_dsGGY[g] + (DSTRIP_GEAR_ROW_H - s_dsGGH[g]) / 2;
      if(mx >= cx && mx < cx + s_dsGGW[g] && my >= cy && my < cy + s_dsGGH[g])
      { DrawStripGridTap(g); return true; }
   }

   // --- the list rows. A row is a full-width CELL (P-DRAW-69: one tone, one
   // owner), so the whole band answers, not just its chip — the same contract
   // the cards' rows have.
   //--- P-DRAW-99: THE CELL IS ONE COLUMN, AND THIS PROBE WAS ASKING THE BOX. The
   //--- paint gives the row `DrawStripGearCellW()` (280) and this asked `colW` =
   //--- `DrawStripGearColW()` — the tab's whole content box, 592 on a 624 tab. The
   //--- gate measures Style and Row wide (624, 7 rows each, 10 and 12 blocks), so on
   //--- both the probe claimed 312px of bare plate to the right of every row in
   //--- column 0: a click on empty card toggled the switch that row names. The
   //--- foot below was already moved off `colW` by P-DRAW-90; the row was the
   //--- reader it did not reach.
   int rowW = DrawStripGearCellW();
   for(int r = 0; r < s_dsGRN && r < DSTRIP_GLIST_MAX; r++)
   {
      int ry = gy + s_dsGRY[r];
      if(my < ry || my >= ry + DSTRIP_GEAR_ROW_H) continue;
      int rx = px + s_dsGRCol[r] * DSTRIP_GEAR_COL;
      if(mx < rx || mx >= rx + rowW) continue;
      //--- P-LVL-COLOR: the level row's swatch (the paint's own chip seat below)
      //--- opens the palette on that stored level; the rest of the row toggles.
      //--- Same seat arrays the paint writes (s_dsGRY/s_dsGRCol) plus the paint's
      //--- own chip constants — no second grid.
      //--- P-LVL-TEXT: the LABEL zone arms the note field; the switch zone and
      //--- the row's padding keep the legacy toggle.
      if(s_dsGRKind[r] == 4)
      {
         int sx = rx + DSTRIP_GEAR_PAD, sy = ry + DSTRIP_CARD_CHIP_Y;
         if(mx >= sx && mx < sx + 22 && my >= sy && my < sy + 22)
         { DrawStripGearLevelColorTap(r); return true; }
         int lx = rx + DSTRIP_GEAR_PAD + 22 + 8;
         int wx = rx + rowW - 40;
         if(mx >= lx && mx < wx)
         { DrawStripGearLevelDescTap(r); return true; }
      }
      DrawStripGearRowTap(r);
      return true;
   }

   // --- the foot (All / Copy). The seats are the paint's own, read not re-derived
   // (4281-4283): the ghost face is `fx-8`, `fy-8`, `bw+16` x `44` around a 28px
   // button at `fy = footY + 10`. The hit box is the GHOST, not the button — a hand
   // aims at the plate it can see, and the ghost is 8px of it on every side.
   const int fpad = 8, fbtnH = 28, ftop = 10;
   int fy0 = gy + s_dsGearFootY;
   //--- P-DRAW-90: the width AND the seat are the paint's own owners now
   //--- (DrawStripFootBw / DrawStripFootX), read here, never re-derived: the old
   //--- `px + f*(bw+gap)` stood in this file and in DrawStripGearPaint at once,
   //--- and the moment `Reset` moves the pair to the right edge the two would
   //--- have disagreed on screen. `colW` is the same DrawStripGearColW() the
   //--- paint passes (280 on a 312 tab, 592 on a 624 one).
   for(int f = 0; f < DSTRIP_GEAR_FOOT_N; f++)
   {
      int bw = DrawStripFootBw(f);
      int fx = DrawStripFootX(f, px, colW);
      int fy = fy0 + ftop;
      if(mx >= fx - fpad && mx < fx + bw + fpad &&
         my >= fy - fpad && my < fy + fbtnH + fpad)
      { DrawStripFootTap(f); return true; }
   }

   return false;   // the plate's own dead space: never a tap
}

bool DrawStripClickFamily()
{
   UISuppressNextClick();
   return true;
}

//--- the slot -> capability map: the strip shows the kind's own controls, in the
//--- order this module declares them, each only where the kind really carries it. A
//--- slot the kind does not carry is SKIPPED, so the strip is never wider than it
//--- needs to be and never shows a control that would do nothing. DELETE lives in
//--- FireDelete (the strip owns it since the menu went); SAVE/ALL are not quick
//--- cells (they ride the more-popover and the gear foot, one tap further). The cap
//--- is EIGHT (P-DRAW-64 -> 64a): worst case DK_RECT = 8 cells + 4 chrome, ~616px,
//--- inside DSTRIP_SKIN_MAXW 660. Past the cap a slot rides the more-popover as an
//--- MK_SLOT row (P-DRAW-08i: a slot past the paint ceiling stays reachable).
void DrawStripVisInit()
{
   if(s_dsVisInit) return;
   s_dsVisInit = true;
   for(int k = 0; k < DK_COUNT; k++)
      for(int s = 0; s < DRAW_SLOT_N; s++) s_dsVis[k][s] = true;
}
bool DrawStripVis(const EDrawKind k, const int slot)
{
   DrawStripVisInit();
   if(k <= DK_NONE || k >= DK_COUNT) return false;
   int seat = (slot == DSTRIP_SLOT_LEVELS) ? DRAW_SLOT_MORE : slot;
   if(seat < 0 || seat >= DRAW_SLOT_N) return true;
   return s_dsVis[k][seat];
}
//--- P-DRAW-64a (2026-09-27) — ONE COLOUR SEAT FOR TWO ROLES. User order: «این
//--- دوتا باکس که برای یک کار هستش میشه باهم ادغام کرد ... میشه یکی بشه». A kind
//--- that carries the interior's colour too shows ONE colour cell whose RING is the
//--- BORDER's colour and whose CENTRE is the interior's (see the paint), so the seat
//--- is `DRAW_SLOT_FILLCLR` and `DRAW_SLOT_COLOR` is folded into it.
//--- P-DRAW-64a: and a KIND-level cap can be finer than it looks. DK_CHANNEL covers
//--- three MT4 types and two of them — the regression and the standard-deviation
//--- channel — have no interior of their own (`DrawTypeHasFillChild`), so the
//--- interior's COLOUR would be a silent no-op there: the seat is not shown at all
//--- (C-04). Asked ONLY for that one kind, so every other kind pays one compare and
//--- no terminal call; the two reads are the channel's own seat, on a repaint.
//--- (The box's own 50 % is NOT in this test: it moves the drawing's own anchor, so
//--- it works on every channel type.)
bool DrawStripSeatAvail(const EDrawKind k, const int slot)
{
   //--- P-UI-139: THE 50 % CELL IS THE PATH'S TOO — a polyline's own answer to it is
   //--- a small circle at each leg's middle. It CANNOT be a KIND rule: a kind rule
   //--- would hand the cell to every plain trendline, and a control nothing answers
   //--- is the one thing this strip refuses (C-04). So the answer is asked of the
   //--- HELD OBJECT, the same way the channel's fill child is asked below — and it is
   //--- asked BEFORE the caps gate, because DK_LINE's caps carry no 50 % bit (the
   //--- rectangle has its own, and this seat is now shared by two owners).
   if(k == DK_LINE && slot == DRAW_SLOT_BOXHALF)
   {
      if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
      return DrawIsPathSeg(s_dsObj);
   }
   if(!DrawSlotAvailable(k, slot)) return false;
   if(k != DK_CHANNEL) return true;
   if(slot != DRAW_SLOT_FILLCLR) return true;
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return true;
   return DrawTypeHasFillChild(DrawObjectType(s_dsObj));
}
bool DrawStripMergedColor(const EDrawKind k)
{
   return (DrawStripSeatAvail(k, DRAW_SLOT_FILLCLR) && DrawSlotAvailable(k, DRAW_SLOT_COLOR));
}
//--- is a seat on the row? The merged colour seat is one seat for two roles, so it
//--- takes the WIDER of the two answers — a control the user asked to see is never
//--- silently dropped by a hide of the other role.
bool DrawStripSeatVis(const EDrawKind k, const int s, const bool merged)
{
   if(merged && s == DRAW_SLOT_FILLCLR)
      return (DrawStripVis(k, DRAW_SLOT_FILLCLR) || DrawStripVis(k, DRAW_SLOT_COLOR));
   return DrawStripVis(k, s);
}
//--- one ordered pass over everything the quick row COULD show (value slots +
//--- LEVELS); the quick cap and the overflow split read this, so the two can
//--- never disagree about order.
int DrawStripAllSlotAt(const EDrawKind k, const int shown)
{
   //--- The order is the module's own (index ascending), with ONE exception: the
   //--- FILL FAMILY reads together — FILL, then the two extras the user asked to
   //--- keep at hand (HALF · EXTEND) — so a box reads "filled · half · extends · …".
   bool merged = DrawStripMergedColor(k);
   //--- P-UI-139: THE 50 % CELL IS A QUICK-ROW CELL FOR A PATH. It is normally held
   //--- back from the walk and re-inserted right after FILL, because a box's fill and
   //--- its two extras read as one family ("filled · half · extends"). A PATH has no
   //--- fill, so that insertion point never arrives and the cell would exist in the
   //--- gear panel and in the writer while being INVISIBLE on the row the user is
   //--- looking at. So for a path the walk keeps the slot at its own index instead:
   //--- after colour/width/style/ray/lock/back, which is where a switch belongs.
   bool pathHalf = (k == DK_LINE && DrawStripSeatAvail(k, DRAW_SLOT_BOXHALF));
   int seen = 0;
   for(int s = 0; s < DRAW_SLOT_N; s++)
   {
      if(s == DRAW_SLOT_MORE) continue;   // no dialog to open from here
      if(merged && s == DRAW_SLOT_COLOR) continue;                 // folded into the colour seat
      if((s == DRAW_SLOT_BOXHALF || s == DRAW_SLOT_EXTEND) && !pathHalf) continue;  // served beside FILL
      if(!DrawStripSeatAvail(k, s)) continue;
      if(!DrawStripSeatVis(k, s, merged)) continue;
      if(seen == shown) return s;
      seen++;
      if(s == DRAW_SLOT_FILL && !pathHalf)
      {
         if(DrawStripSeatAvail(k, DRAW_SLOT_BOXHALF) && DrawStripVis(k, DRAW_SLOT_BOXHALF))
         {
            if(seen == shown) return DRAW_SLOT_BOXHALF;
            seen++;
         }
         if(DrawSlotAvailable(k, DRAW_SLOT_EXTEND) && DrawStripVis(k, DRAW_SLOT_EXTEND))
         {
            if(seen == shown) return DRAW_SLOT_EXTEND;
            seen++;
         }
      }
   }
   if(DrawKindHasLevels(k) && DrawStripVis(k, DSTRIP_SLOT_LEVELS))
   {
      if(seen == shown) return DSTRIP_SLOT_LEVELS;
      seen++;
   }
   return -1;
}
int DrawStripAllSlotCount(const EDrawKind k)
{
   int n = 0;
   while(DrawStripAllSlotAt(k, n) != -1 && n < DSTRIP_MAX_SLOTS + 4) n++;
   return n;
}
int DrawStripQuickSlotAt(const EDrawKind k, const int shown)
{
   if(shown < 0 || shown >= DSTRIP_QUICK_CAP) return -1;
   return DrawStripAllSlotAt(k, shown);
}
int DrawStripQuickCount(const EDrawKind k)
{
   int n = DrawStripAllSlotCount(k);
   if(n > DSTRIP_QUICK_CAP) n = DSTRIP_QUICK_CAP;
   return n;
}
int DrawStripOverflowSlotAt(const EDrawKind k, const int shown)
{
   if(shown < 0) return -1;
   return DrawStripAllSlotAt(k, DSTRIP_QUICK_CAP + shown);
}
int DrawStripOverflowCount(const EDrawKind k)
{
   int n = DrawStripAllSlotCount(k) - DSTRIP_QUICK_CAP;
   return (n > 0 ? n : 0);
}

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-10 — THE ICON FACE.
// ══════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-13 — EVERY QUICK CELL WEARS A RASTER (icon-only row). State carriers
// vary per value (width/style/ray — the P-DRAW-10 honesty rule); pure glyphs
// ride one raster and the gold face carries the state; the colour cell is a
// swatch (no raster, ""), its face IS the object's colour (P-DRAW-09c).
// ══════════════════════════════════════════════════════════════════════════
string DrawStripIconRes(const int slot, const string nm)
{
   //--- P-DRAW-64a: the colour seat wears no raster — its face IS the two colours it
   //--- edits (the border's ring and the interior's centre), which is the answer
   //--- DRAW_SLOT_COLOR always gave. The droplet that told the two cells apart went
   //--- with the merge; the seat is one cell now, so nothing needs telling apart.
   if(DrawStripIsColorSlot(slot)) return "";
   //--- P-DRAW-64a: the fill family's two extras. OFF is the plate ink, ON the
   //--- amber twin, so the ON cell stays quiet (one shape on the accent wash).
   if(slot == DRAW_SLOT_BOXHALF)
   {
      // P-UI-139/140 (2026-10-02, MEASURED: a tap meant for this cell landed on
      // `slot=9 Behind candles`, because a PATH wore the BOX's block art beside two
      // other block glyphs). The path answers with its OWN face — two legs with a
      // dot on each middle — so no hand has to guess which of three block icons is
      // the marker. One raster pair, the same 24 canvas, the same amber twin.
      if(DrawIsPathSeg(nm))
         return ((DrawSlotRead(nm, DRAW_SLOT_BOXHALF) > 0.5) ? "::Files\\Icons\\bk_mid_on.bmp"
                                                             : "::Files\\Icons\\bk_mid_off.bmp");
      return ((DrawSlotRead(nm, DRAW_SLOT_BOXHALF) > 0.5) ? "::Files\\Icons\\bk_half_on.bmp"
                                                          : "::Files\\Icons\\bk_half_off.bmp");
   }
   if(slot == DRAW_SLOT_EXTEND)
      return ((DrawSlotRead(nm, DRAW_SLOT_EXTEND) > 0.5) ? "::Files\\Icons\\bk_ext_on.bmp"
                                                         : "::Files\\Icons\\bk_ext_off.bmp");
   if(slot == DRAW_SLOT_WIDTH)
   {
      int w = (int)DrawSlotRead(nm, DRAW_SLOT_WIDTH);
      if(w < DRAW_WIDTH_MIN || w > DRAW_WIDTH_MAX) w = DRAW_WIDTH_MIN;
      return "::Files\\Icons\\bk_w" + IntegerToString(w) + ".bmp";
   }
   if(slot == DRAW_SLOT_STYLE)
   {
      int st = (int)DrawSlotRead(nm, DRAW_SLOT_STYLE);
      if(st < 0) st = 0;
      // P-LOOK: a look wears its native icon (no baked glyphs for looks).
      else if(st > 4) st = FibPenLookNative(st - 4);
      if(st < 0 || st > 4) st = 0;
      return "::Files\\Icons\\bk_style" + IntegerToString(st) + ".bmp";
   }
   //--- P-DRAW-BODY-UI: the handle's own width/style reuse the level family's
   //--- rasters (same seats, no new art) — read off the body's own slots, so the
   //--- two width cells can never show each other's value.
   if(slot == DRAW_SLOT_BODYWIDTH)
   {
      int bw = (int)DrawSlotRead(nm, DRAW_SLOT_BODYWIDTH);
      if(bw < DRAW_WIDTH_MIN || bw > DRAW_WIDTH_MAX) bw = DRAW_WIDTH_MIN;
      return "::Files\\Icons\\bk_w" + IntegerToString(bw) + ".bmp";
   }
   if(slot == DRAW_SLOT_BODYSTYLE)
   {
      int bs = (int)DrawSlotRead(nm, DRAW_SLOT_BODYSTYLE);
      if(bs < 0 || bs > 4) bs = 0;
      return "::Files\\Icons\\bk_style" + IntegerToString(bs) + ".bmp";
   }
   if(slot == DRAW_SLOT_RAY)
   {
      int r = (int)DrawSlotRead(nm, DRAW_SLOT_RAY);
      if(r < 0 || r > 3) r = 0;
      return "::Files\\Icons\\bk_ray" + IntegerToString(r) + ".bmp";
   }
   if(slot == DRAW_SLOT_FILL)
      return ((DrawSlotRead(nm, DRAW_SLOT_FILL) > 0.5) ? "::Files\\Icons\\bk_fill_on.bmp"
                                                       : "::Files\\Icons\\bk_bucket.bmp");
   //--- P-DRAW-47: the ON faces are the AMBER twins (`bk_*_on` / `bk_lock_on_g`).
   //--- Their dark-ink predecessors were drawn for a solid gold plate, while the
   //--- ON face here is a translucent WASH — measured, the dark art's own mean
   //--- luminance is ~12 against a wash whose premultiplied mean is (33,22,0), so
   //--- ON read as NO glyph at all. The preview's rule is accent ink on the wash.
   if(slot == DRAW_SLOT_LOCK)
      return ((DrawSlotRead(nm, DRAW_SLOT_LOCK) > 0.5) ? "::Files\\Icons\\bk_lock_on_g.bmp"
                                                       : "::Files\\Icons\\bk_lock_off.bmp");
   //--- P-UI-131 (2026-10-02): the BACK seat wears ONE shape in two inks, like every
   //--- other toggle in this row. It used to answer `gl_layers_m` when off (grey
   //--- chevrons, 26 px) and `bk_back_on` when on (amber overlapping rects, 24 px) —
   //--- two glyphs and two canvases for one control, which is why the live tap
   //--- («رنگ fill باکس رو خاموش و روشن میکنه») read as the wrong button even though
   //--- the witness proves the write was exact. `bk_back_off` is its own art in the
   //--- plate ink, baked by the generator beside `bk_back_on` (see gen-th3-icons.js).
   if(slot == DRAW_SLOT_BACK)
      return ((DrawSlotRead(nm, DRAW_SLOT_BACK) > 0.5) ? "::Files\\Icons\\bk_back_on.bmp"
                                                       : "::Files\\Icons\\bk_back_off.bmp");
   if(slot == DRAW_SLOT_FONT) return "::Files\\Icons\\gl_textsize_m.bmp";
   if(slot == DRAW_SLOT_GLYPH) return "::Files\\Icons\\bk_glyph.bmp";
   if(slot == DSTRIP_SLOT_LEVELS) return "::Files\\Icons\\bk_levels.bmp";
   return "";
}
//--- chrome faces: grip, badge has none (text label), actions by seat.
string DrawStripActRes(const int a)
{
   if(a == DSTRIP_ACT_MORE) return "::Files\\Icons\\bk_more.bmp";
   if(a == DSTRIP_ACT_GEAR) return "::Files\\Icons\\bk_gear.bmp";
   if(a == DSTRIP_ACT_PIN)
      return (s_dsPinned ? "::Files\\Icons\\gl_pin_gold.bmp" : "::Files\\Icons\\gl_pin_m.bmp");
   //--- P-BK-111: ONE glyph, and it is a TWO-HEADED arrow. The cell has three states, not
   //--- two, so the usual pair of faces would be wrong twice: a single-headed up arrow
   //--- reads as «this box is a BUY», which is a claim the strip cannot make (the side
   //--- belongs to the knot layer, and the user may have overridden it). A shape that can
   //--- go both ways is the only honest face for a cell whose job is to change the side.
   if(a == DSTRIP_ACT_DIR) return "::Files\\Icons\\bk_dirflip.bmp";
   if(a == DSTRIP_ACT_DEL) return "::Files\\Icons\\bk_del.bmp";
   return "";
}

//--- MT4 paints a bitmap label at the file's NATIVE size from the label's own
//--- top-left corner, so centring the art is arithmetic — and the arithmetic
//--- needs the art's size. The families in this strip are fixed:
//---   every `bk_*` = 24, `gl_*` = 15 — and the four 26px `gl_*` glyphs, named
//---   in the table below.
//--- (Measured off the shipped files; a new family must be added here, which is
//--- what keeps a 24 px raster from hanging off a 30 px cell.)
//--- P-DRAW-106 (2026-10-01): AND THE `bk_w` / `bk_style` / `bk_ray` EXCEPTION IS
//--- RETIRED. It answered 16 for those three chips, but the shipped rasters are
//--- 24x24 with the glyph centred in its own canvas (measured on Files/Icons: all
//--- 32 `bk_*.bmp` the strip names are 24x24; `bk_w1.bmp`'s ink is 16 wide at
//--- x4..19 of a 24 canvas) — so `x + (cell - 16)/2` placed each chip's art 4px
//--- right and 4px down of its cell's centre, on the strip's width/style/ray cell
//--- and on the settings panel's Style chips alike. The FILE is what MT4 draws,
//--- so the file's canvas is what this table must answer.
int DrawStripIconPx(const string res)
{
   if(StringFind(res, "gl_") >= 0) return 15;
   if(StringFind(res, "bk_") >= 0) return 24;
   return 0;
}
int DrawStripResW(const string res)
{
   // P-UI-34: W-variants are 624px (wide panel header); narrow variants are 312px.
   if(StringFind(res, "pnl_topbarW") >= 0 || StringFind(res, "pnl_hairW") >= 0) return 624;
   if(StringFind(res, "pnl_topbar") >= 0 || StringFind(res, "pnl_hair") >= 0) return 312;
   if(StringFind(res, "pnl_mark") >= 0) return 44;
   if(StringFind(res, "dsg_btn") >= 0) return 80;
   if(StringFind(res, "pnl_sw_") >= 0) return 52;
    // P-UI-34 (2026-09-25): sheen sizes must be known for correct centring —
    // without an entry here DrawStripFaceZ gets pw=0 and places the art at the
    // cell's own centre instead of its corner. ICON-DIET 2026-09-27: the two
    // pnl_glass entries left with their bitmaps (see the #resource block).
    if(StringFind(res, "ds_cell32") >= 0) return 32;
    if(StringFind(res, "ds_ring32") >= 0) return 32;
    if(StringFind(res, "ds_swatch24") >= 0) return 24;
    if(StringFind(res, "pnl_chip") >= 0) return 26;
    if(StringFind(res, "pnl_rail") >= 0) return 4;
    if(StringFind(res, "pnl_vchip") >= 0) return 50;
    if(StringFind(res, "pnl_xbtn") >= 0) return 30;
   if(StringFind(res, "pnl_secdot") >= 0) return 14;   // P-DRAW-71: the cards' own section dot
   //--- P-DRAW-108 (2026-10-01) — AND THIS RULE WAS NEVER COMPILED. It stood on the
   //--- `secdot` line, AFTER that line's own `//` comment, so the MQL compiler read
   //--- the whole `if` as comment text: `DrawStripResW("::Files\\Icons\\pnl_cntchip.bmp")`
   //--- fell through to `DrawStripIconPx`'s 0 for a 28x20 canvas, and the section's
   //--- count pill — painted by DrawStripFaceZ in a rect `DSTRIP_SEC_CNT_W + 4` wide,
   //--- DrawStrip_GearB.mqh:842 — landed at `x + 28/2, y + 20/2`: 14px right and 10px
   //--- down of its own rect, with MT4 cropping the 24px art to what was left of it.
   //--- The gate missed it for the same reason: tools/check-resources.js split the
   //--- table on `;` and kept every `//` tail, so a commented-out rule was read as
   //--- LIVE and answered a right number by accident. A one-line statement is not a
   //--- one-line change — the rule owns its line now.
   if(StringFind(res, "pnl_cntchip") >= 0) return 28;  // ... and its count pill (24+2*2)
   if(StringFind(res, "pnl_subdot") >= 0) return 8;
   //--- P-DRAW-106 (2026-10-01) — THE FOOT'S OWN GHOST, WHICH THIS TABLE DID NOT
   //--- CARRY. `pnl_btn_ghost.bmp` is 88x44 (measured on the file) and had no
   //--- entry, so it fell through to `DrawStripIconPx`'s 0 — and `DrawStripFaceZ`
   //--- centres a raster in its cell as `x + (w - pw)/2`, which with `pw = 0` is
   //--- HALF THE CELL. The gear panel's foot asks for the ghost as
   //--- `(fx - 8, fy - 8, bw + 16, 44)`, i.e. the 72x28 button plus its 8px pad, so
   //--- the three plates shipped at `fx + 36, fy + 14`: 44px right of the button and
   //--- 22px below it — off the label each one belongs to, the last one 19px past the
   //--- card's right edge and all of them under the plate's bottom edge. One missing
   //--- number, three dead-looking foot buttons, and a green compile says nothing
   //--- (the size is a number in a chain of string tests, not a symbol).
   //--- The same audit measured `gl_pin*`, `gl_textsize*` and `gl_layers*`: 26x26
   //--- canvases inside a `gl_` family this table calls 15, so each of those arts
   //--- sat 5.5px right and down of its cell (the strip's pin cell and the FONT
   //--- chip are the two the panel paints).
   if(StringFind(res, "pnl_btn_ghost") >= 0) return 88;
   if(StringFind(res, "gl_pin") >= 0 || StringFind(res, "gl_textsize") >= 0 ||
      StringFind(res, "gl_layers") >= 0) return 26;
   return DrawStripIconPx(res);
}
int DrawStripResH(const string res)
{
   if(StringFind(res, "pnl_topbarW") >= 0) return 7;
   if(StringFind(res, "pnl_hairW") >= 0) return 5;
   if(StringFind(res, "pnl_topbar") >= 0) return 7;
   if(StringFind(res, "pnl_hair") >= 0) return 5;
   if(StringFind(res, "pnl_mark") >= 0) return 44;
   if(StringFind(res, "dsg_btn") >= 0) return 44;
   if(StringFind(res, "pnl_sw_") >= 0) return 34;
    // P-UI-34 (2026-09-25): glass sheen heights. ICON-DIET 2026-09-27: the
    // pnl_glass pair left with its bitmaps (see the #resource block).
    if(StringFind(res, "ds_cell32") >= 0) return 32;
    if(StringFind(res, "ds_ring32") >= 0) return 32;
    if(StringFind(res, "ds_swatch24") >= 0) return 24;
    if(StringFind(res, "pnl_chip") >= 0) return 26;
    if(StringFind(res, "pnl_rail") >= 0) return 42;
   if(StringFind(res, "pnl_vchip") >= 0) return 26;
   if(StringFind(res, "pnl_xbtn") >= 0) return 30;
   if(StringFind(res, "pnl_secdot") >= 0) return 14;
   if(StringFind(res, "pnl_cntchip") >= 0) return 20;
   if(StringFind(res, "pnl_subdot") >= 0) return 8;
   if(StringFind(res, "pnl_btn_ghost") >= 0) return 44;   // P-DRAW-106, see ResW
   if(StringFind(res, "gl_pin") >= 0 || StringFind(res, "gl_textsize") >= 0 ||
      StringFind(res, "gl_layers") >= 0) return 26;       // P-DRAW-106, see ResW
   return DrawStripIconPx(res);
}

//--- P-DRAW-09c — THE CELL'S TWO READING AIDS.
//
// 1. THE COLOUR CELL SHOWS A NAME A TRADER CAN READ. `ColorToString` says
//    `clrWhite` (a programming name) or `C'255,128,0'` (a compiler literal).
//    Neither is a caption: the first loses its spaces — `clrDodgerBlue` — and the
//    second is unreadable at a glance. So the MT4 names are un-CamelCased into
//    words («Dodger Blue») and anything else becomes the hex the rest of the
//    industry shows («#FF8000»), which is both modern and exact.
//
// 2. AND ITS INK CONTRASTS WITH THE SWATCH. The cell's face IS the object's
//    colour (that is what makes it a swatch), so the label sits on a colour the
//    user chose — and this project already paid for this lesson once (P-UI-69,
//    «رنگ ها کار نمیکنه»: an invisible control reads as a broken one). The maths
//    is WCAG's relative luminance, the same one `PnlLum` uses; it is local
//    because its owner (`BiotakPanels.mqh`) is included after this module.
// ══════════════════════════════════════════════════════════════════════════
double DrawStripLum(const color c)
{
   // `color` is UNSIGNED in MQL4, so `c < 0` is always false (warning 65): a
   // stray clrNONE only shows up once the value is seen as a signed int.
   int v = (int)c;
   if(v < 0) return 1.0;
   double r = (double)(v % 256) / 255.0;
   double g = (double)((v / 256) % 256) / 255.0;
   double b = (double)(v / 65536) / 255.0;
   if(r > 0.03928) r = MathPow((r + 0.055) / 1.055, 2.4); else r = r / 12.92;
   if(g > 0.03928) g = MathPow((g + 0.055) / 1.055, 2.4); else g = g / 12.92;
   if(b > 0.03928) b = MathPow((b + 0.055) / 1.055, 2.4); else b = b / 12.92;
   return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

color DrawStripInkOn(const color bg)
{
   // the threshold sits where the eye does: above it the face is light, so the
   // ink is the dark plate's own ink; below it, the light one. No colour is
   // rejected — the swatch keeps the user's exact colour either way.
   return (DrawStripLum(bg) > 0.45) ? DSTRIP_CLR_ACCENTT : DSTRIP_CLR_LABEL;
}

string DrawStripColorLabel(const color c)
{
   string s = ColorToString(c, false);
   if(StringFind(s, "clr") == 0)
   {
      s = StringSubstr(s, 3);
      string out = "";
      for(int i = 0; i < StringLen(s); i++)
      {
         // a capital that is not the first character starts a new word (a plain
         // character-code test: `StringToUpper(ch)` on a one-char string costs a
         // temporary and warns on some builds' implicit conversions)
         int code = StringGetCharacter(s, i);
         if(i > 0 && code >= 'A' && code <= 'Z') out += " ";
         out += StringSubstr(s, i, 1);
      }
      if(StringLen(out) > 10) out = StringSubstr(out, 0, 10);
      return out;
   }
   // `C'r,g,b'` -> `#RRGGBB`
   int nOpen = StringFind(s, "'");
   int nClose = StringFind(s, "'", nOpen + 1);
   if(nOpen >= 0 && nClose > nOpen)
   {
      string t = StringSubstr(s, nOpen + 1, nClose - nOpen - 1);
      int p1 = StringFind(t, ",");
      int p2 = StringFind(t, ",", p1 + 1);
      if(p1 > 0 && p2 > p1)
      {
         int r = (int)StringToInteger(StringSubstr(t, 0, p1));
         int g = (int)StringToInteger(StringSubstr(t, p1 + 1, p2 - p1 - 1));
         int b = (int)StringToInteger(StringSubstr(t, p2 + 1, StringLen(t) - p2 - 1));
         return StringFormat("#%02X%02X%02X", r, g, b);
      }
   }
   return "Color";   // P-UI-69d: ONE spelling in user-visible text (`Color`), like the one verb
}
#endif // DRAW_STRIP_BASE_MQH
// DrawStrip_Pick.mqh - DrawStrip split 2026-09-29: exact lines 1461-2380 of DrawStrip.mqh, byte-identical, zero renames.
#ifndef DRAW_STRIP_PICK_MQH
#define DRAW_STRIP_PICK_MQH


//--- the caption of one slot, always the CURRENT value (a value the user can
//--- read is worth more than a glyph they must learn — and the icons never
//--- REPLACE the state, they carry it: see the tooltips below).
//--- the WORD of one value (tooltips, grid chips, gear rows). Quick cells are
//--- icon-only and never read this; the words live where a value must be read.
string DrawStripSlotText(const EDrawKind k, const int slot, const string nm)
{
   if(slot == DSTRIP_SLOT_LEVELS) return "Levels";
   switch(slot)
   {
      case DRAW_SLOT_COLOR:
      {
         color c = (color)(int)DrawSlotRead(nm, DRAW_SLOT_COLOR);
         return DrawStripColorLabel(c);
      }
      case DRAW_SLOT_FILLCLR:
         return DrawStripColorLabel((color)(int)DrawSlotRead(nm, DRAW_SLOT_FILLCLR)) +
                " " + IntegerToString(DrawSlotAlphaGet(nm, DRAW_SLOT_FILLCLR)) + "%";
      case DRAW_SLOT_WIDTH:
         return IntegerToString((int)DrawSlotRead(nm, DRAW_SLOT_WIDTH)) + "px";
      case DRAW_SLOT_STYLE:
      {
         int st = (int)DrawSlotRead(nm, DRAW_SLOT_STYLE);
         if(st == FIBPEN_STYLE_NEON) return "Neon";
         if(st == FIBPEN_STYLE_CAPS) return "Caps";
         if(st == FIBPEN_STYLE_WASH) return "Wash";
         if(st == STYLE_DASH) return "Dash";
         if(st == STYLE_DOT) return "Dot";
         if(st == STYLE_DASHDOT) return "D-Dash";
         if(st == STYLE_DASHDOTDOT) return "D-Dot";
         return "Solid";
      }
      case DRAW_SLOT_FILL:
         // P-DRAW-65: a row NAMES its feature and the switch shows the state —
         // "Empty" was the OFF-state wearing the label's own seat (C-05/C-08).
         return (DrawSlotRead(nm, DRAW_SLOT_FILL) > 0.5) ? "Interior on" : "Interior off";
      case DRAW_SLOT_BOXHALF:
         // P-UI-139: the cell's WORDS follow the drawing that answers it — a path
         // shows markers, not a line, and a row that names the wrong feature is the
         // C-05/C-08 failure the FILL row above already answers.
         if(DrawIsPathSeg(nm))
            return (DrawSlotRead(nm, DRAW_SLOT_BOXHALF) > 0.5) ? "50% dots on" : "50% dots off";
         return (DrawSlotRead(nm, DRAW_SLOT_BOXHALF) > 0.5) ? "50 % line on" : "50 % line off";
      case DRAW_SLOT_EXTEND:
         return (DrawSlotRead(nm, DRAW_SLOT_EXTEND) > 0.5) ? "Extend right on" : "Extend right off";
      case DRAW_SLOT_RAY:
      {
         int r = (int)DrawSlotRead(nm, DRAW_SLOT_RAY);
         if(r == 1) return "Ray>";
         if(r == 2) return "<Ray";
         if(r == 3) return "<Ray>";
         return "Segment";
      }
      case DRAW_SLOT_LOCK:
         return (DrawSlotRead(nm, DRAW_SLOT_LOCK) > 0.5) ? "Lock on" : "Lock off";
      //--- P-DRAW-09a: the three appended controls. GLYPH shows the CODE, which
      //--- is the honest caption for a Wingdings mark the user is cycling to —
      //--- MT4's own dialog is where a number like 233 has to be typed.
      case DRAW_SLOT_FONT:
         return IntegerToString((int)DrawSlotRead(nm, DRAW_SLOT_FONT)) + "pt";
      case DRAW_SLOT_GLYPH:
         return "G" + IntegerToString((int)DrawSlotRead(nm, DRAW_SLOT_GLYPH));
      case DRAW_SLOT_BACK:
         // the slot IS `OBJPROP_BACK`, so the word follows the slot, not the wish
         return (DrawSlotRead(nm, DRAW_SLOT_BACK) > 0.5) ? "Layer: behind" : "Layer: front";
      //--- P-DRAW-BODY-UI: the handle's words carry the "Handle" name, so the two
      //--- width cells (and the two style cells) never read as one value twice.
      case DRAW_SLOT_BODYCOLOR:
         return DrawStripColorLabel((color)(int)DrawSlotRead(nm, DRAW_SLOT_BODYCOLOR));
      case DRAW_SLOT_BODYWIDTH:
         return "Handle " + IntegerToString((int)DrawSlotRead(nm, DRAW_SLOT_BODYWIDTH)) + "px";
      case DRAW_SLOT_BODYSTYLE:
      {
         int bs = (int)DrawSlotRead(nm, DRAW_SLOT_BODYSTYLE);
         if(bs == STYLE_DASH) return "Handle Dash";
         if(bs == STYLE_DOT) return "Handle Dot";
         if(bs == STYLE_DASHDOT) return "Handle D-Dash";
         if(bs == STYLE_DASHDOTDOT) return "Handle D-Dot";
         return "Handle Solid";
      }
      default: return "";
   }
}

//--- P-DRAW-68: A ROW THAT CARRIES A SWITCH NAMES ITS FEATURE. `DrawStripSlotText`
//--- above is the QUICK ROW's cell caption — 32px wide, no switch, so the state has
//--- to live in the words. The settings panel's row is 280px wide and already wears
//--- a 40px switch, so the same string read the state twice ("Interior off" beside an
//--- OFF switch) and broke C-05/C-08 — the cards' own switch rows are all bare
//--- features ("MID ZONES", "SHOW LINES", "MAGNET"). Two questions, two owners.
string DrawStripSwitchName(const string nm, const int slot)
{
   if(slot == DRAW_SLOT_FILL)    return "Interior";
   // P-UI-139: the 50 % seat names what the HELD drawing makes of it — markers on a
   // path, the mid line on a rectangle.
   if(slot == DRAW_SLOT_BOXHALF) return (DrawIsPathSeg(nm) ? "50% markers" : "50 % line");
   if(slot == DRAW_SLOT_EXTEND)  return "Extend right";
   if(slot == DRAW_SLOT_LOCK)    return "Lock";
   if(slot == DRAW_SLOT_BACK)    return "Behind candles";
   return DrawStripSlotText(s_dsKind, slot, nm);
}

//--- P-DRAW-11: the option lists, one owner per slot, so the picker and the
//--- write can never disagree about the list. The arrow marks are the small
//--- curated set traders actually use (Wingdings codes 233/234 are the classic
//--- up/down arrows), and the code number stays visible in the caption.
int DrawStripGlyphAt(const int i)
{
   static int gl[8] = {233, 234, 235, 236, 241, 242, 225, 226};
   if(i < 0 || i >= 8) return gl[0];
   return gl[i];
}
int DrawStripFontAt(const int i)
{
   static int fs[6] = {8, 10, 12, 14, 18, 24};
   if(i < 0 || i >= 6) return fs[0];
   return fs[i];
}
int DrawStripFontCount() { return 6; }
int DrawStripGlyphCount() { return 8; }

//--- P-PAL-21 (2026-10-02) — THE HEADER'S RIGHT CLUSTER IS GONE WITH THE BOARD. The
//--- page arrows, the «1/2» and the studio's ring were seats on a plate that no
//--- longer exists (a colour cell now opens the CARDS' palette, P-PAL-19), so the
//--- three macros that owned their geometry — and the four accessors that placed
//--- them — went with the board. `DrawStripPickGlyphCount` and the list rows below
//--- are the picker that is still real.
//--- TV parity board (2026-09-26): the recents are a BAND of their own now, so the
//--- grid indexer and the dedupe face that fed it (`DrawStripPickPalIndex`,
//--- `DrawStripRecentExtra`, `DrawStripPickSwatchAt`) were reachable only through
//--- each other and went with the change.
//--- the trader's own recent colours: deduped, newest first, capped.
void DrawStripRecentPush(const color c)
{
   int at = -1;
   for(int i = 0; i < s_dsRecentN; i++) if(s_dsRecent[i] == c) { at = i; break; }
   if(at == 0) return;
   if(at > 0) { for(int j = at; j > 0; j--) s_dsRecent[j] = s_dsRecent[j - 1]; }
   else
   {
      if(s_dsRecentN < DSTRIP_RECENT_MAX) s_dsRecentN++;
      for(int k = s_dsRecentN - 1; k > 0; k--) s_dsRecent[k] = s_dsRecent[k - 1];
   }
   s_dsRecent[0] = c;
}
bool DrawStripHasPicker(const int slot)
{
   //--- P-DRAW-BODY-UI: BODYCOLOR rides the palette via IsColorSlot; the handle's
   //--- width/style open the same list picker as the levels' pair.
   return (DrawStripIsColorSlot(slot) || slot == DRAW_SLOT_WIDTH ||
           slot == DRAW_SLOT_STYLE || slot == DRAW_SLOT_RAY ||
           slot == DRAW_SLOT_FONT  || slot == DRAW_SLOT_GLYPH ||
           slot == DRAW_SLOT_BODYWIDTH || slot == DRAW_SLOT_BODYSTYLE ||
           slot == DSTRIP_SLOT_LEVELS);
}
bool DrawStripIsToggle(const int slot)
{
   return (slot == DRAW_SLOT_FILL || slot == DRAW_SLOT_LOCK || slot == DRAW_SLOT_BACK ||
           slot == DRAW_SLOT_BOXHALF || slot == DRAW_SLOT_EXTEND);
}
//--- how many options this popover shows right now (LEVELS = membership rows).
int DrawStripPickCount(const EDrawKind k, const int slot)
{
   //--- P-PAL-21: a colour seat has NO rows here any more — the list picker is the
   //--- one that is left, and a colour seat's editor is the CARDS' popup.
   if(slot == DRAW_SLOT_WIDTH || slot == DRAW_SLOT_BODYWIDTH) return 5;
   // P-LOOK: the fibo's own looks ride the STYLE slot as 5/6/7 — same writer,
   // same highlight, same undo; other kinds keep the native five.
   //--- P-DRAW-BODY-UI: the handle's style is the native five only (no looks).
   if(slot == DRAW_SLOT_BODYSTYLE) return 5;
   if(slot == DRAW_SLOT_STYLE) return ((k == DK_FIBO || k == DK_FIBOFAN) ? 8 : 5);
   if(slot == DRAW_SLOT_RAY) return 4;
   if(slot == DRAW_SLOT_FONT) return DrawStripFontCount();
   if(slot == DRAW_SLOT_GLYPH) return DrawStripGlyphCount();
   if(slot == DSTRIP_SLOT_LEVELS) return DrawStripGearLevelCount();
   return 0;
}
//--- the option's colour (the list rows carry no colour; clrNONE throughout —
//--- P-PAL-21 took the colour grid with the board).
color DrawStripPickColor(const int slot, const int row)
{
   return clrNONE;
}
//--- the option's caption (colour cells are swatches: no text, tooltip speaks).
string DrawStripPickText(const EDrawKind k, const int slot, const int row)
{
   if(slot == DRAW_SLOT_WIDTH || slot == DRAW_SLOT_BODYWIDTH)
   {
      if(row < 0 || row > 4) return "";
      return IntegerToString(row + 1) + "px";
   }
   //--- P-DRAW-BODY-UI: native five only — a handle never wears a look.
   if(slot == DRAW_SLOT_BODYSTYLE)
   {
      if(row == 1) return "Dash";
      if(row == 2) return "Dot";
      if(row == 3) return "D-Dash";
      if(row == 4) return "D-Dot";
      if(row == 0) return "Solid";
      return "";
   }
   if(slot == DRAW_SLOT_STYLE)
   {
      if(row == 1) return "Dash";
      if(row == 2) return "Dot";
      if(row == 3) return "D-Dash";
      if(row == 4) return "D-Dot";
      if(row == FIBPEN_STYLE_NEON && (k == DK_FIBO || k == DK_FIBOFAN)) return "Neon";
      if(row == FIBPEN_STYLE_CAPS && (k == DK_FIBO || k == DK_FIBOFAN)) return "Caps";
      if(row == FIBPEN_STYLE_WASH && (k == DK_FIBO || k == DK_FIBOFAN)) return "Wash";
      if(row == 0) return "Solid";
      return "";
   }
   if(slot == DRAW_SLOT_RAY)
   {
      if(row == 1) return "Ray>";
      if(row == 2) return "<Ray";
      if(row == 3) return "<Ray>";
      if(row == 0) return "Segment";
      return "";
   }
   if(slot == DRAW_SLOT_FONT)
   {
      if(row < 0 || row >= DrawStripFontCount()) return "";
      return IntegerToString(DrawStripFontAt(row)) + "pt";
   }
   if(slot == DRAW_SLOT_GLYPH)
   {
      if(row < 0 || row >= DrawStripGlyphCount()) return "";
      return "G" + IntegerToString(DrawStripGlyphAt(row));
   }
   return "";
}
//--- is this option the one the drawing wears now (the gold pill)?
bool DrawStripPickIsCur(const string nm, const EDrawKind k, const int slot, const int row)
{
   if(DrawStripIsColorSlot(slot))
   {
      color c = DrawStripPickColor(slot, row);
      return (c != clrNONE && (color)(int)DrawSlotRead(nm, slot) == c);
   }
   if(slot == DRAW_SLOT_WIDTH) return ((int)DrawSlotRead(nm, DRAW_SLOT_WIDTH) == row + 1);
   if(slot == DRAW_SLOT_BODYWIDTH) return ((int)DrawSlotRead(nm, DRAW_SLOT_BODYWIDTH) == row + 1);
   if(slot == DRAW_SLOT_BODYSTYLE) return ((int)DrawSlotRead(nm, DRAW_SLOT_BODYSTYLE) == row);
   if(slot == DRAW_SLOT_STYLE) return ((int)DrawSlotRead(nm, DRAW_SLOT_STYLE) == row);
   if(slot == DRAW_SLOT_RAY)   return ((int)DrawSlotRead(nm, DRAW_SLOT_RAY) == row);
   if(slot == DRAW_SLOT_FONT)  return ((int)DrawSlotRead(nm, DRAW_SLOT_FONT) == DrawStripFontAt(row));
   if(slot == DRAW_SLOT_GLYPH) return ((int)DrawSlotRead(nm, DRAW_SLOT_GLYPH) == DrawStripGlyphAt(row));
   return false;
}

int DrawStripColorHoverCellAt(const int mx, const int my)
{
   if(!s_dsOpen) return -1;
   //--- P-DRAW-118 (2026-10-01): the SWATCH cells live in the Color group's quick
   //--- rows now (they were the retired Paint grid's, the last caller this fence
   //--- knew). Same seat arrays, one more group allowed to wear them.
   if(s_dsGear == DSTRIP_GEAR_STYLE || s_dsGear == DSTRIP_GEAR_PAINT)
   {
      for(int g = 0; g < s_dsGGN; g++)
      {
         if(s_dsGGKind[g] != DSTRIP_GRG_SWATCH) continue;
          int x = DrawStripGearX() + s_dsGGX[g], y = s_dsGEY + s_dsGGY[g] + (DSTRIP_GEAR_ROW_H - s_dsGGH[g]) / 2;
          if(mx >= x && mx <= x + s_dsGGW[g] && my >= y && my <= y + s_dsGGH[g]) return g;

      }
   }
   //--- P-DRAW-48: the colour board's bands are the BOARD's (its own origin), so
   //--- the hover must read them there — the strip's origin previewed the colour of
   //--- a phantom cell one row away (reported: the pointer sits on one colour and
   //--- the drawing takes another).
   if(DrawStripIsColorSlot(s_dsPicker) && s_dsBW > 0 && s_dsBH > 0)
   {
      // TV parity board: the grid's own cells, then the RECENT band's.
      for(int r = 0; r < s_dsPN; r++)
      {
          int x = s_dsBX + DSTRIP_PAD + (r % BIOPICK_COLS) * (DSTRIP_PICK_CELL + DSTRIP_PICK_GAP);
          int y = s_dsBY + s_dsPY[r] + (DSTRIP_PICK_ROW - DSTRIP_PICK_CELL) / 2;
          if(mx >= x && mx <= x + DSTRIP_PICK_CELL && my >= y && my <= y + DSTRIP_PICK_CELL)

            return DSTRIP_HOVER_POP_BASE + r;
      }
      if(s_dsPRecY >= 0)
      {
         int ry = s_dsBY + s_dsPRecY + (DSTRIP_PICK_ROW - DSTRIP_PICK_CELL) / 2;
         for(int i = 0; i < s_dsRecentN; i++)
         {
            int rx = s_dsBX + DSTRIP_PAD + DSTRIP_PREC_LW + i * (DSTRIP_PICK_CELL + DSTRIP_PICK_GAP);
            if(mx >= rx && mx <= rx + DSTRIP_PICK_CELL && my >= ry && my <= ry + DSTRIP_PICK_CELL)
               return DSTRIP_HOVER_REC_BASE + i;
         }
      }
   }
   return -1;
}

color DrawStripColorHoverValue(const int cell)
{
   // TV parity board: the RECENT band is tested FIRST (its base is the higher one).
   if(cell >= DSTRIP_HOVER_REC_BASE)
   {
      int i = cell - DSTRIP_HOVER_REC_BASE;
      if(!DrawStripIsColorSlot(s_dsPicker) || i < 0 || i >= s_dsRecentN) return clrNONE;
      return s_dsRecent[i];
   }
   if(cell >= DSTRIP_HOVER_POP_BASE)
   {
      int r = cell - DSTRIP_HOVER_POP_BASE;
      if(!DrawStripIsColorSlot(s_dsPicker) || r < 0 || r >= s_dsPN) return clrNONE;
      return DrawStripPickColor(s_dsPicker, r);
   }
   if(cell < 0 || cell >= s_dsGGN || s_dsGGKind[cell] != DSTRIP_GRG_SWATCH) return clrNONE;
   return s_dsGGC[cell];
}

void DrawStripColorHoverFace(const int cell, const bool active)
{
   string nm;
   bool current = false;
   if(cell >= DSTRIP_HOVER_REC_BASE)
   {
      int i = cell - DSTRIP_HOVER_REC_BASE;
      if(!DrawStripIsColorSlot(s_dsPicker) || i < 0 || i >= s_dsRecentN) return;
      nm = DrawStripPRecName(i);
      current = (s_dsRecent[i] == DrawStripColorRead(s_dsObj, s_dsPicker));
   }
   else if(cell >= DSTRIP_HOVER_POP_BASE)
   {
      int r = cell - DSTRIP_HOVER_POP_BASE;
      if(!DrawStripIsColorSlot(s_dsPicker) || r < 0 || r >= s_dsPN) return;
      nm = DrawStripPickName(r);
      current = DrawStripPickIsCur(s_dsObj, s_dsKind, s_dsPicker, r);
   }
   else
   {
      if(cell < 0 || cell >= s_dsGGN || s_dsGGKind[cell] != DSTRIP_GRG_SWATCH) return;
      nm = DrawStripGridName(cell);
      //--- P-DRAW-118: the CELL says which role it belongs to — the FILL row's
      //--- swatches compare against the interior, not against the border.
      current = (DrawStripColorRead(s_dsObj, s_dsGGSlot[cell]) == s_dsGGC[cell]);
   }
   if(ObjectFind(0, nm) < 0) return;
   //--- P-UI-69b: the RESTORED rim is the swatch legibility floor, not a bare
   //--- hairline, so the leave-restore lands on exactly what the paint wrote.
   //--- DrawStripColorHoverValue() answers clrNONE for a non-swatch cell and
   //--- BioSwatchBorder reads clrNONE as white, i.e. the hairline — the old rim.
   color rim = (active || current) ? DSTRIP_CLR_ACCENT
                                   : BioSwatchBorder(DrawStripColorHoverValue(cell), BIO_CLR_CARD);
   if((color)ObjectGetInteger(0, nm, OBJPROP_BORDER_COLOR) != rim)
      ObjectSetInteger(0, nm, OBJPROP_BORDER_COLOR, rim);
}

void DrawStripPalPreview(const int cell)
{
   color c = DrawStripColorHoverValue(cell);
   if(c == clrNONE) return;
   for(int i = 0; i < s_dsPalN; i++)
   {
      if(s_dsPicker == DRAW_SLOT_FILLCLR) DrawSlotPreviewFillColor(s_dsPalName[i], c);
      else DrawSlotPreviewColor(s_dsPalName[i], c);
   }
   DrawStripColorHoverFace(cell, true);
   ChartRedraw();
}
void DrawStripPalHighlightEnd()
{
   if(s_dsPalCell >= 0) DrawStripColorHoverFace(s_dsPalCell, false);
   s_dsPalCell = -1;
}
//--- where the scrub's preview points. `-1` = off the palette (the hand left the
//--- grid): the drawing wears its OWN pixels again, because a preview that lingered
//--- off the grid would be a colour the user never released on.
void DrawStripPalTo(const int cell)
{
   if(cell == s_dsPalCell) return;
   if(s_dsPalCell >= 0) DrawStripColorHoverFace(s_dsPalCell, false);
   s_dsPalCell = cell;
   if(cell >= 0) { DrawStripPalPreview(cell); return; }
   for(int i = 0; i < s_dsPalN; i++) DrawSlotRenderRestore(s_dsPalName[i]);
   ChartRedraw();
}

//--- P-DRAW-64 (2026-09-27) — THE HOVER LIGHTS THE CELL, NEVER THE CHART.
//--- Report: «من این شفافیت تنظیم میکنم موس میره روی بقیه رنگه ناخواسته شفافیت
//--- [از دست میره]» — the cell under the pointer used to be written onto the
//--- DRAWING as a live preview (P-DRAW-27). That write went straight to
//--- `OBJPROP_COLOR`, i.e. the PURE colour OUTSIDE the one render owner, so the tone
//--- the user had just tuned on the bar fell back to full strength the moment the
//--- hand crossed a cell on its way to the ✕. A hover is therefore a HIGHLIGHT only
//--- (`.swcell` rim lighting — what a picker is expected to do, and the cheaper path:
//--- not one object write per hovered cell, G-09); the chart preview now rides the
//--- PRESS-DRAG SCRUB above it, which is a deliberate gesture that ENDS in a commit.
void DrawStripColorHoverAt(const int mx, const int my)
{
   int cell = DrawStripColorHoverCellAt(mx, my);
   if(cell == s_dsColorHoverCell) return;
   int old = s_dsColorHoverCell;
   s_dsColorHoverCell = cell;
   if(old >= 0) DrawStripColorHoverFace(old, false);
   if(cell >= 0) DrawStripColorHoverFace(cell, true);
   ChartRedraw();   // the BOARD's own rim moved; the drawing was not touched
}

void DrawStripColorHoverClear()
{
   int old = s_dsColorHoverCell;
   s_dsColorHoverCell = -1;
   if(old >= 0) DrawStripColorHoverFace(old, false);
   //--- P-DRAW-64: "nothing is highlighted" means nothing is PREVIEWED either —
   //--- every close/dismissal path already comes through here, so a scrub that met
   //--- its own end (✕, Esc, another surface, the strip closing) leaves the drawing
   //--- wearing the pixels its tags say. The GRAB flag stays: the view lock belongs
   //--- to the one ender (`DrawStripGripRelease`).
   DrawStripPalTo(-1);
}

//--- APPLY one picker row: moved after DrawStripWriteValue (MQL4 is
//--- define-before-use), see below. The contract lives here: through the group
//--- fan-out (P-DRAW-09b), learning the look for the next drawing (P-DRAW-01c).

//--- P-DRAW-09b (retired 2026-10-03): the scope line is GONE, and it is always
//--- empty — `DrawSelCount()` is 1 by construction now (the served drawing), so the
//--- suffix could never print «applies to all 2 selected». Kept as one function with
//--- one answer so every tip that appends it stays honest: a tap changes the drawing
//--- the strip is on, and only that one.
string DrawStripTipScope()
{
   return "";
}

//--- P-DRAW-13: an icon cell's tooltip is where its VALUE is read (the face
//--- carries the picture, the words live here), so the value is interpolated.
string DrawStripSlotTip(const EDrawKind k, const int slot, const string nm)
{
   string scope = DrawStripTipScope();
   switch(slot)
   {
      case DRAW_SLOT_COLOR:
         return "Border color: " + DrawStripColorLabel((color)(int)DrawSlotRead(nm, DRAW_SLOT_COLOR)) +
                " — click to choose" + scope;
      case DRAW_SLOT_FILLCLR:
         return "Fill color: " + DrawStripColorLabel((color)(int)DrawSlotRead(nm, DRAW_SLOT_FILLCLR)) +
                " at " + IntegerToString(DrawSlotAlphaGet(nm, DRAW_SLOT_FILLCLR)) +
                "% (" + DrawStripSlotText(k, DRAW_SLOT_FILL, nm) + ") — click to choose, then drag the bar" + scope;
      case DRAW_SLOT_WIDTH:
         return "Line width: " + IntegerToString((int)DrawSlotRead(nm, DRAW_SLOT_WIDTH)) +
                " px — click to choose" + scope;
      case DRAW_SLOT_STYLE:
         return "Line style: " + DrawStripSlotText(k, DRAW_SLOT_STYLE, nm) +
                " — click to choose" + scope;
      case DRAW_SLOT_FILL:
         return "Fill: " + DrawStripSlotText(k, DRAW_SLOT_FILL, nm) + " — click to toggle" + scope;
      case DRAW_SLOT_RAY:
         return "Ray: " + DrawStripSlotText(k, DRAW_SLOT_RAY, nm) +
                " — click to choose segment/ray/both" + scope;
      case DRAW_SLOT_LOCK:
         return "Lock: " + DrawStripSlotText(k, DRAW_SLOT_LOCK, nm) +
                " — a locked drawing cannot be moved or edited" + scope;
      case DRAW_SLOT_BOXHALF:
         // P-UI-139: the same cell, two answers — a rectangle draws a line at its own
         // middle, a PATH a small circle at each leg's middle. A tooltip that names
         // the other's feature is the C-05/C-08 lie in a longer coat.
         if(DrawIsPathSeg(nm))
            return "50% markers: " + DrawStripSlotText(k, DRAW_SLOT_BOXHALF, nm) +
                   " — a small circle at the middle of every leg; the path keeps the" +
                   " shape you drew" + scope;
         return "50% level: " + DrawStripSlotText(k, DRAW_SLOT_BOXHALF, nm) +
                " — a line at the box's own middle, like a fib level; the box keeps the" +
                " length you drew" + scope;
      case DRAW_SLOT_EXTEND:
         return "Extend right: " + DrawStripSlotText(k, DRAW_SLOT_EXTEND, nm) +
                " — the far edge jumps to the newest bar at once, then travels with" +
                " each new bar (the \"...\" list has the" +
                " other modes: to first touch, or N bars)" + scope;
      case DRAW_SLOT_FONT:
         return "Text size: " + IntegerToString((int)DrawSlotRead(nm, DRAW_SLOT_FONT)) +
                " pt — click to choose" + scope;
      case DRAW_SLOT_GLYPH:
         return "Arrow mark: glyph " + IntegerToString((int)DrawSlotRead(nm, DRAW_SLOT_GLYPH)) +
                " — click to choose" + scope;
      case DRAW_SLOT_BACK:
         return "Behind the candles: " + DrawStripSlotText(k, DRAW_SLOT_BACK, nm) +
                " — click to toggle" + scope;
      case DRAW_SLOT_BODYCOLOR:
         return "Handle color: " + DrawStripColorLabel((color)(int)DrawSlotRead(nm, DRAW_SLOT_BODYCOLOR)) +
                " — click to choose" + scope;
      case DRAW_SLOT_BODYWIDTH:
         return "Handle width: " + IntegerToString((int)DrawSlotRead(nm, DRAW_SLOT_BODYWIDTH)) +
                " px — click to choose" + scope;
      case DRAW_SLOT_BODYSTYLE:
         return "Handle style: " + DrawStripSlotText(k, DRAW_SLOT_BODYSTYLE, nm) +
                " — click to choose" + scope;
      default: break;
   }
   if(slot == DSTRIP_SLOT_LEVELS)
      return "Levels: " + IntegerToString(DrawLevelCount(nm)) + " on — click to edit membership" +
             " (the held drawing; MT4 draws every level it has)";
   return "";
}
//--- P-DRAW-64a: the merged colour seat's two halves, each with its own words —
//--- MT4 shows whichever layer the hand is over, so the seat explains itself
//--- without a mode to remember.
string DrawStripColorRingTip(const string nm, const bool merged)
{
   string t = "Border color: " + DrawStripColorLabel((color)(int)DrawSlotRead(nm, DRAW_SLOT_COLOR)) +
              " — click the TOP bar for its palette";
   if(merged)
      t += ", or the BOTTOM bar for the fill's color (" +
           DrawStripColorLabel((color)(int)DrawSlotRead(nm, DRAW_SLOT_FILLCLR)) + " at " +
           IntegerToString(DrawSlotAlphaGet(nm, DRAW_SLOT_FILLCLR)) + "%)";
   return t + DrawStripTipScope();
}
string DrawStripColorMidTip(const string nm)
{
   return "Fill color: " + DrawStripColorLabel((color)(int)DrawSlotRead(nm, DRAW_SLOT_FILLCLR)) +
          " at " + IntegerToString(DrawSlotAlphaGet(nm, DRAW_SLOT_FILLCLR)) + " — " +
          ((DrawSlotRead(nm, DRAW_SLOT_FILL) > 0.5) ? "Filled" : "Empty") +
          " — click the BOTTOM bar for its palette, then drag the TR track" + DrawStripTipScope();
}
//--- chrome tooltips: grip/badge/actions.
string DrawStripActTip(const int a)
{
   if(a == DSTRIP_ACT_MORE) return "More: apply-to-all, templates, duplicate, undo";
   if(a == DSTRIP_ACT_GEAR) return "Full settings: style, levels, template, strip";
   if(a == DSTRIP_ACT_PIN) return (s_dsPinned ? "Pinned: outside click won't dismiss — click to unpin"
                                              : "Pin: keep the strip while editing");
   //--- P-BK-111: THE CAPTION STATES BOTH HALVES OF THE CYCLE, because a caption that
   //--- only says «flip» leaves the user guessing how to hand the box back to the market
   //--- — and the answer (click again) IS the third state. On a drawing that is not a
   //--- Base Box it says exactly that, instead of promising a change it cannot make.
   if(a == DSTRIP_ACT_DIR)
   {
      string id = BaseKnotDirBoxFor(s_dsObj);
      if(id == "") return "Direction: flips a BASE BOX's side — this drawing is not one";
      if(BaseKnotDirLocked(id)) return "Back to automatic: let the price pick this box's side (it is " + BaseKnotDirWord(id) + ")";
      return "Trade this box the other way — it is " + BaseKnotDirWord(id) + ", click again to let the price decide";
   }
   if(a == DSTRIP_ACT_DEL)
   {
      //--- P-DRAW-09b retired (2026-10-03): the bin is this drawing's bin. The strip
      //--- serves one object, so the «these N drawings» wording could never be true.
      return "Delete this drawing (not undoable)";
   }
   return "";
}

//--- P-DRAW-11: the option's tooltip — the value AND the group it will change.
string DrawStripPickTip(const string nm, const EDrawKind k, const int slot, const int row)
{
   string scope = DrawStripTipScope();
   if(DrawStripIsColorSlot(slot))
   {
      color c = DrawStripPickColor(slot, row);
      if(c == clrNONE) return "";
      return (slot == DRAW_SLOT_FILLCLR ? "Fill color: " : "Border color: ") +
             DrawStripColorLabel(c) + " — click to apply" + scope;
   }
   string t = DrawStripPickText(k, slot, row);
   if(t == "") return "";
   return t + " — click to apply" + scope;
}

//--- which cells wear the "this is ON" face. ONE function, so no cell can
//--- disagree with the state it reports.
bool DrawStripSlotOn(const int slot, const string nm)
{
   if(slot == DRAW_SLOT_FILL) return (DrawSlotRead(nm, DRAW_SLOT_FILL) > 0.5);
   if(slot == DRAW_SLOT_LOCK) return (DrawSlotRead(nm, DRAW_SLOT_LOCK) > 0.5);
   if(slot == DRAW_SLOT_BACK) return (DrawSlotRead(nm, DRAW_SLOT_BACK) > 0.5);
   if(slot == DRAW_SLOT_BOXHALF) return (DrawSlotRead(nm, DRAW_SLOT_BOXHALF) > 0.5);
   if(slot == DRAW_SLOT_EXTEND) return (DrawSlotRead(nm, DRAW_SLOT_EXTEND) > 0.5);
   return false;
}

//--- P-DRAW-09c: the badge text. ONE owner of what the strip says it is serving.
//--- P-DRAW-09b retired (2026-10-03): the `xN` count is GONE — the strip serves ONE
//--- drawing, so a count on the badge would be a number the strip could never honour.
string DrawStripTitle()
{
   if(s_dsObj == "") return "";
   return DrawKindName(s_dsKind);
}

//--- P-DRAW-13: the LEVELS union both the popover and the gear tab read — the
//--- nine common values plus the drawing's own customs, capped. ONE builder so
//--- P-LVL-SCALE (2026-10-04) — MT4 STORES RATIOS, THE PANEL SHOWS PERCENT.
//--- `OBJPROP_LEVELVALUE` is a ratio (MQL5 book journal: 0.236, 0.618, 1.0;
//--- measured on-chart: customs 0.3/0.7/1.0 land at 30/70/100%). The old common
//--- list stored 23.6 (=2360%, off-chart) and the add field's own example
//--- ("88.6") stored 8860% — «این سطح درست اضافه نمیشه». ONE normalizer: a value
//--- at percent scale (|v|>=10, the two-digit labels the panel itself shows)
//--- rides /100; a ratio rides as-is. Old percent-stored sets migrate through
//--- `DrawStripLevelsCollect`, the one funnel into every rewrite.
double DrawStripLevelNorm(const double v)
{
   if(!MathIsValidNumber(v)) return v;
   if(MathAbs(v) >= 10.0) return v / 100.0;
   return v;
}
//--- the two editors can never disagree about row i.
bool DrawStripLevelIsCommon(const double v)
{
   double nv = DrawStripLevelNorm(v);
   for(int j = 0; j < DrawStripLevelCommonCount(); j++)
      if(MathAbs(DrawStripLevelCommon(j) - nv) < 0.000001) return true;
   return false;
}
int DrawStripGearLevelCount()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return 0;
   if(!DrawKindHasLevels(s_dsKind)) return 0;
   int n = DrawStripLevelCommonCount();
   int cur = DrawLevelCount(s_dsObj);
   for(int i = 0; i < cur && n < DSTRIP_GLIST_MAX; i++)
   {
      double v = DrawStripLevelNorm(DrawLevelValue(s_dsObj, i));
      if(!MathIsValidNumber(v)) continue;
      if(DrawStripLevelIsCommon(v)) continue;
      bool dup = false;
      for(int j = 0; j < i; j++)
         if(MathAbs(DrawStripLevelNorm(DrawLevelValue(s_dsObj, j)) - v) < 0.000001) { dup = true; break; }
      if(!dup) n++;
   }
   if(n > DSTRIP_GLIST_MAX) n = DSTRIP_GLIST_MAX;
   return n;
}
double DrawStripGearLevelAt(const int row)
{
   int nc = DrawStripLevelCommonCount();
   if(row >= 0 && row < nc) return DrawStripLevelCommon(row);
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return EMPTY_VALUE;
   int seen = nc;
   int cur = DrawLevelCount(s_dsObj);
   for(int i = 0; i < cur; i++)
   {
      double v = DrawStripLevelNorm(DrawLevelValue(s_dsObj, i));
      if(!MathIsValidNumber(v)) continue;
      if(DrawStripLevelIsCommon(v)) continue;
      bool dup = false;
      for(int j = 0; j < i; j++)
         if(MathAbs(DrawStripLevelNorm(DrawLevelValue(s_dsObj, j)) - v) < 0.000001) { dup = true; break; }
      if(dup) continue;
      if(seen == row) return v;
      seen++;
      if(seen >= DSTRIP_GLIST_MAX) break;
   }
   return EMPTY_VALUE;
}

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-13 — THE FIBO LEVEL-MEMBERSHIP EDITOR. MT4 draws every level a fibo
// HAS, so there is no per-level visibility to toggle: the editor edits
// MEMBERSHIP (add/remove values), which is the power MT4 buries four dialogs
// deep. Structural: it rewrites the HELD drawing's level set only (a group
// with different sets has no well-defined union to edit).
// ══════════════════════════════════════════════════════════════════════════
double DrawStripLevelCommon(const int i)
{
   //--- P-LVL-SCALE: stored ratios (MT4 truth), shown percent (panel labels).
   switch(i)
   {
      case 0: return 0.0;
      case 1: return 0.236;
      case 2: return 0.382;
      case 3: return 0.5;
      case 4: return 0.618;
      case 5: return 0.786;
      case 6: return 1.0;
      case 7: return 1.272;
      default: return 1.618;
   }
}
int DrawStripLevelCommonCount() { return 9; }
string DrawStripLevelName(const double v)
{
   //--- P-LVL-SCALE: the label is percent ("23.6"), the value a ratio (0.236).
   if(!MathIsValidNumber(v)) return "";
   double nv = DrawStripLevelNorm(v);
   string s = DoubleToString(nv * 100.0, 1);
   if(StringLen(s) > 2 && StringSubstr(s, StringLen(s) - 2) == ".0")
      s = StringSubstr(s, 0, StringLen(s) - 2);
   return s;
}
int DrawStripLevelFind(const string nm, const double v)
{
   //--- P-LVL-SCALE: compare normalized — an old percent-stored set (23.6) still
   //--- answers its row (0.236) instead of duplicating beside it.
   double nv = DrawStripLevelNorm(v);
   int n = DrawLevelCount(nm);
   for(int i = 0; i < n; i++)
      if(MathAbs(DrawStripLevelNorm(DrawLevelValue(nm, i)) - nv) < 0.000001) return i;
   return -1;
}

//--- DIAG-136 (2026-10-02) — DOES THE BOX WEAR THE INK IT OWNS?
//--- Two different failures answer to one complaint, so they get two witnesses. The
//--- 2 s pass already walks every rectangle, so this is where a chart-side fact can be
//--- cheap: it is called ONLY for a rectangle the product itself coloured (a `[CL…]`
//--- tag), which is one `StringFind` for everybody else and nothing at all.
//--- THE QUESTION, in the order that settles it: (1) the pure colour the box owns, read
//--- off its own tag; (2) what the chart must wear at that opacity, via the ONE blend
//--- owner (`DrawSlotRenderColor`) — so this witness can never disagree with what the
//--- colour write would have produced; (3) what it ACTUALLY wears.
//--- VERDICT, and each arm is a DIFFERENT bug:
//---   MISMATCH — the object wears something no write produced (a stale repaint, a
//---            foreign writer, a terminal reset): the eyes are on an ink nobody chose.
//---   INVISIBLE — the ink equals the chart background: the border is drawn and cannot
//---            be seen. This is «اصلا رنگ نمیکره» in its literal form, and it is the one
//---            arm a screenshot alone cannot distinguish from «no box».
//--- SILENT WHEN HEALTHY, which is the point: a chart with fifty correct boxes writes
//--- nothing, so the line that IS there is the whole finding.
void BoxInkWitness(const string nm)
{
   static string lastSig = "";
   if(nm == "" || ObjectFind(0, nm) < 0) return;
   color pure = clrNONE;
   if(!DrawSlotColorPure(nm, pure)) return;          // not ours — one StringFind
   color want = DrawSlotRenderColor(nm, pure);
   int have = (int)ObjectGetInteger(0, nm, OBJPROP_COLOR);
   color bg = GetCachedChartBgColor();
   bool invisible = (MathAbs(have - (int)bg) <= 2);
   bool mismatch = (MathAbs(have - (int)want) > 2);
   if(!invisible && !mismatch) return;
   string sig = nm + "|" + IntegerToString(have) + "|" + IntegerToString((int)want) +
                "|" + IntegerToString((int)bg);
   if(sig == lastSig) return;                         // one line per DISTINCT state
   lastSig = sig;
   DrawStripDiagEmit("[drawstrip] BOXCLEAR name=\"" + nm + "\" " +
                     (invisible ? "INVISIBLE" : "MISMATCH") +
                     " have=" + IntegerToString(have) +
                     " want=" + IntegerToString((int)want) +
                     " pure=" + IntegerToString((int)pure) +
                     " bg=" + IntegerToString((int)bg) +
                     " opacity=" + IntegerToString(DrawSlotOpacityGet(nm)));
}

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-21/22 — BOX EXTRAS: the 50% line and the user-driven extend.
// Two things MT4's rectangle cannot do: draw its own middle, or reach into the
// future. Both live OUTSIDE the native object:
//   * the mid line is a child OBJ_TREND `<box>_BX50` (DrawToolbar.mqh owns the
//     suffix; the classifier answers DK_NONE for it, so it is never served,
//     never hit-tested, never learned);
//   * the mark itself (`[BX50]` mid, `[BXE1]`/`[BXE2]`/`[BXE3:N]` far edge,
//     `[BXH]` half interior — P-DRAW-64a) is the description channel; its reader
//     and writer moved DOWN to DrawToolbar.mqh with the two SLOTS the user
//     ordered, so both stand above the slot reader (MQL4 define-before-use).
// Everything below is the GEOMETRY those marks drive. The pump (BoxExtrasPump,
// from RefreshKitOnBar) is the only per-tick reader: 2 s throttle, or at once on a
// new bar — a still chart costs one iTime read. Undo stays look-only: an extend
// moves TIME, not the look.
// ══════════════════════════════════════════════════════════════════════════
bool BoxAnchors(const string name, datetime &t0, double &p0, datetime &t1, double &p1)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   t0 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
   p0 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
   t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
   p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
   return (t0 > 0 && t1 > 0 && p0 > 0.0 && p1 > 0.0);
}
void BoxSetInt(const string nm, const int prop, const long v)
{
   if(ObjectGetInteger(0, nm, prop) != v) ObjectSetInteger(0, nm, prop, v);
}
void BoxSetColor(const string nm, const int prop, const color c)
{
   if((color)(int)ObjectGetInteger(0, nm, prop) != c) ObjectSetInteger(0, nm, prop, c);
}
//--- how far the 50 % line's ink steps back towards the chart background, in percent.
//--- 55 is the number that reads as a guide on both schemes: present enough to aim at,
//--- quiet enough that a box wearing it is not the loudest thing on the chart.
#define BOX_MID_FADE 55
bool BoxMidSync(const string box)
{
   if(box == "" || ObjectFind(0, box) < 0) return false;
   if(DrawObjectType(box) != OBJ_RECTANGLE) return false;
   bool want = false; int ext = BOXEXT_OFF, extN = 0;
   BoxMarkRead(box, want, ext, extN);
   string ch = BoxMidName(box);
   if(!want)
   {
      if(ObjectFind(0, ch) >= 0) ObjectDelete(0, ch);
      return false;
   }
   datetime t0 = 0, t1 = 0; double p0 = 0.0, p1 = 0.0;
   if(!BoxAnchors(box, t0, p0, t1, p1))
   {
      if(ObjectFind(0, ch) >= 0) ObjectDelete(0, ch);
      return false;
   }
   double mp = (p0 + p1) / 2.0;
   if(ObjectFind(0, ch) < 0)
   {
      if(!ObjectCreate(0, ch, OBJ_TREND, 0, t0, mp, t1, mp)) return false;
      ObjectSetInteger(0, ch, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ch, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, ch, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, ch, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, ch, OBJPROP_RAY_RIGHT, false);
      //--- P-DRAW-64a (2026-09-27) — THE LEVEL IS A WHISPER, AND WHISPERS ARE SET ONCE.
      //--- User order: «خط وسط باید نازک تر ... مینمال باشه که چارت شلوغ نشه». Two lines
      //--- did that: the width MIRRORED the box's own (a 2-3 px dotted rule in the same
      //--- ink as the border — the busiest thing a quiet box can wear), and the ink was
      //--- the master's at FULL strength. Now the frame is written here, at birth, and
      //--- never read or written again: 1 px (the thinnest MT4 draws) and STYLE_DOT, so
      //--- the steady state's per-frame cost loses a read AND a compare, and the line is
      //--- the minimum the terminal can put on the chart.
      ObjectSetInteger(0, ch, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, ch, OBJPROP_STYLE, STYLE_DOT);
   }
   else
   {
      //--- P-DRAW-64d: the moves are guarded, so an unthrottled stream costs reads
      //--- and never a repaint it did not earn. A drag event for a box that did not
      //--- move (a click, a selection) used to re-stamp two anchors and invalidate
      //--- the line for nothing; now it is four reads and two compares.
      datetime ct0 = (datetime)ObjectGetInteger(0, ch, OBJPROP_TIME, 0);
      double cp0 = ObjectGetDouble(0, ch, OBJPROP_PRICE, 0);
      datetime ct1 = (datetime)ObjectGetInteger(0, ch, OBJPROP_TIME, 1);
      double cp1 = ObjectGetDouble(0, ch, OBJPROP_PRICE, 1);
      if(ct0 != t0 || cp0 != mp) ObjectMove(0, ch, 0, t0, mp);
      if(ct1 != t1 || cp1 != mp) ObjectMove(0, ch, 1, t1, mp);
   }
   //--- and the INK recedes: the master's own PURE colour blended most of the way
   //--- to the chart background. Reads [CL] first: OBJPROP_COLOR is already the
   //--- blend, re-blending it each sync walks any colour to black in ~20 frames.
   color mc = clrNONE;
   if(!DrawSlotColorPure(box, mc)) mc = (color)(int)ObjectGetInteger(0, box, OBJPROP_COLOR);
   BoxSetColor(ch, OBJPROP_COLOR, BlendColorTowardsBG(mc, BOX_MID_FADE, GetCachedChartBgColor()));
   BoxSetInt(ch, OBJPROP_BACK, ObjectGetInteger(0, box, OBJPROP_BACK));
   return true;
}
void BoxMidDrop(const string box)
{
   if(box == "") return;
   string ch = BoxMidName(box);
   if(ObjectFind(0, ch) >= 0) ObjectDelete(0, ch);
}
void BoxMidSyncServed() { if(s_dsKind == DK_RECT && s_dsObj != "") BoxMidSync(s_dsObj); }
//--- P-DRAW-64a (2026-09-27) — THE LEVEL FOLLOWS THE BORDER'S INK, ON EVERY COMMIT.
//--- Found in the cross-tool pass: the 50 % line wears the border's colour (blended
//--- 55 %), but NO border-colour commit re-inked it — grid, recent, hex and tone all
//--- wrote the box and left the line wearing the OLD blend until the pump's 2 s pass.
//--- So every border-colour commit asks this, and the group gets the same fan-out the
//--- fill's own show has (`DrawStripFillShowGroup`). One description read per member,
//--- a write only when the ink really changed, nothing at rest.
void BoxMidSyncGroup()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return;
   DrawSelPrune();
   int n = DrawSelCount();
   if(n <= 0) { BoxMidSync(s_dsObj); return; }
   for(int i = 0; i < n; i++) BoxMidSync(DrawSelAt(i));
}
//--- P-DRAW-64c (2026-09-27) — THE FIRST STEP IS THE TAP'S, NOT THE NEXT BAR'S.
//--- The pump steps a travelling edge only on a new bar (`ext != OFF && newBar`), so a
//--- box whose edge sat weeks back showed NOTHING for up to a whole bar period after the
//--- tap — on H1, an hour of a gold button on a static box («دکمه اکستند باکس رو به جلو
//--- اکستند نمیکنه»). The tap therefore takes the first step itself, and the pump keeps
//--- it travelling from there. Same fan-out as the mid's: one guarded step per member,
//--- a no-op where the edge is already at the front or the mode is off.
void BoxExtendStepGroup()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return;
   DrawSelPrune();
   int n = DrawSelCount();
   if(n <= 0) { BoxExtendStep(s_dsObj); return; }
   for(int i = 0; i < n; i++) BoxExtendStep(DrawSelAt(i));
}
//--- P-UI-132 (2026-10-02) — THE EDGE THE MODE TOOK IS THE EDGE IT GIVES BACK.
//--- User report (one sentence, two defects): «وقتی اکستند کلیک میکنم 50 درصد باکس خاموش
//--- و روشن نمیشه چرا تداخل داره و اینکه اکستند خاموش میکنم بر نمیگرده به حالت اول».
//--- MEASURED in the code, not guessed: `DrawSlotWrite`'s EXTEND arm writes `[BXE2]`
//--- and NOTHING else (Biotak/Toolbar_B.mqh), while the tap's own first step
//--- (`BoxExtendStepGroup`, P-DRAW-64c) moves the box's LATER anchor onto the forming
//--- bar. So arming the mode changes the drawing permanently and disarming it only
//--- stops the travel — the box never comes back, which is the second half of the
//--- report in one sentence. The first half is the same fact seen from the other
//--- control: the 50 % is a LEVEL at the box's mid PRICE (`BoxMidSync`), so it does
//--- not fight the edge over a price — it RIDES the edge to the far end of the chart,
//--- and two cells that move together read as one cell interfering with the other.
//--- THE MEMO: two numbers and the side that was later, written once at the arming and
//--- spent once at the disarming. A ring of eight names in file scope — NOT a
//--- descriptor tag: the marks block is rewritten by every writer (`BoxMarkWrite`
//--- re-emits `[BX50]`/`[BXE…]` and would drop anything else), and P-DRAW-64a's third
//--- cut already removed a remembered payload once. Nothing here runs on the paint or
//--- the pump path, so a still chart pays zero, and the memo dies with the name rather
//--- than going stale: a box whose mode was armed before a terminal restart simply
//--- keeps the edge it travelled to, which is today's behaviour.
#define BOX_EDGE_MEMO 8
static string   s_bxeName[BOX_EDGE_MEMO];
static datetime s_bxeT[BOX_EDGE_MEMO];
static double   s_bxeP[BOX_EDGE_MEMO];
static int      s_bxeLi[BOX_EDGE_MEMO];

int BoxEdgeSlot(const string name)
{
   for(int i = 0; i < BOX_EDGE_MEMO; i++) if(s_bxeName[i] == name) return i;
   return -1;
}
void BoxEdgeForget(const string name)
{
   int i = BoxEdgeSlot(name);
   if(i < 0) return;
   s_bxeName[i] = ""; s_bxeT[i] = 0; s_bxeP[i] = 0.0; s_bxeLi[i] = 0;
}
bool BoxEdgeRemember(const string name)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   if(DrawObjectType(name) != OBJ_RECTANGLE) return false;
   datetime t0 = 0, t1 = 0; double p0 = 0.0, p1 = 0.0;
   if(!BoxAnchors(name, t0, p0, t1, p1)) return false;
   int li = (t1 >= t0) ? 1 : 0;
   int i = BoxEdgeSlot(name);
   if(i < 0)
   {
      for(int k = 0; k < BOX_EDGE_MEMO; k++) if(s_bxeName[k] == "") { i = k; break; }
      if(i < 0) { BoxEdgeForget(s_bxeName[0]); i = 0; }   // nine armed boxes: the oldest goes
   }
   s_bxeName[i] = name;
   s_bxeLi[i]   = li;
   s_bxeT[i]    = (li == 1) ? t1 : t0;
   s_bxeP[i]    = (li == 1) ? p1 : p0;
   return true;
}
//--- the disarm spends the memo: the edge goes back where the hand put it, and the two
//--- drawings that follow the box get the SAME frame — the 50 % line and the interior.
bool BoxEdgeRestore(const string name)
{
   int i = BoxEdgeSlot(name);
   if(i < 0) return false;
   datetime t = s_bxeT[i];
   double   p = s_bxeP[i];
   int      li = s_bxeLi[i];
   BoxEdgeForget(name);                    // spent first: a throw cannot spend it twice
   if(name == "" || ObjectFind(0, name) < 0) return false;
   bool moved = false;
   //--- MQL4 has no `ObjectSetInteger(..., OBJPROP_PRICE, index, v)` (error 230: the
   //--- enumerator takes no modifier), so an ANCHOR goes home the one way the terminal
   //--- accepts: `ObjectMove` with both of its numbers. Two reads decide whether it is
   //--- needed at all, so a disarm on an untouched edge writes nothing.
   datetime ct = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, li);
   double   cp = ObjectGetDouble(0, name, OBJPROP_PRICE, li);
   if(ct != t || MathAbs(cp - p) > 0.0) { ObjectMove(0, name, li, t, p); moved = true; }
   if(!moved) return false;
   BoxMidSync(name);      // the 50 % rides the edge: it must be re-synced on the way back
   FillChildSync(name);   // ...and so does the interior (P-DRAW-64a: a moved edge, a moved interior)
   DrawStripDiagEmit("[drawstrip] EDGE restored name=\"" + name + "\" t=" + IntegerToString((int)t) +
                     " p=" + DoubleToString(p, 5));
   return true;
}
void BoxEdgeRememberGroup()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return;
   DrawSelPrune();
   int n = DrawSelCount();
   if(n <= 0) { BoxEdgeRemember(s_dsObj); return; }
   for(int i = 0; i < n; i++) BoxEdgeRemember(DrawSelAt(i));
}
void BoxEdgeRestoreGroup()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return;
   DrawSelPrune();
   int n = DrawSelCount();
   if(n <= 0) { BoxEdgeRestore(s_dsObj); return; }
   for(int i = 0; i < n; i++) BoxEdgeRestore(DrawSelAt(i));
}
//--- P-DRAW-64a, third cut: there is NO recheck any more. The 50 % used to be a
//--- remembered LENGTH, so a hand that gave the box a new length had to drop the mark
//--- (else the next tap restored a length the user never chose). A 50 % LEVEL is a
//--- line at the box's own mid PRICE: it is TRUE for every box, at every length, in
//--- every position, so there is no payload to go stale and nothing to re-check.
//--- the extend cycle the strip row taps: off -> to touch -> to end ->
//--- 8 -> 16 -> 32 bars -> off. A tap mid-countdown turns it off outright.
int BoxExtCycle(const string name)
{
   bool mid = false; int ext = BOXEXT_OFF, n = 0;
   BoxMarkRead(name, mid, ext, n);
   int prev = ext;
   if(ext == BOXEXT_OFF) { ext = BOXEXT_TOUCH; n = 0; }
   else if(ext == BOXEXT_TOUCH) { ext = BOXEXT_END; n = 0; }
   else if(ext == BOXEXT_END) { ext = BOXEXT_NBARS; n = 8; }
   else if(ext == BOXEXT_NBARS && n <= 8) n = 16;
   else if(ext == BOXEXT_NBARS && n <= 16) n = 32;
   else { ext = BOXEXT_OFF; n = 0; }
   //--- P-UI-132 addendum: the cycle's ARMING half is the cell's arming half, so it
   //--- spends the same memo — measured, not guessed: this row arms the mode and
   //--- (`BoxExtendStep`, below it) moves the edge on the very same tap, while the
   //--- disarm half already restored from a memo this half never wrote. So the cycle
   //--- could stretch a box and never give it back — the report, on one of its two
   //--- doors. Guarded on the TRANSITION, not on `ext != OFF`: an already-armed box
   //--- walking its modes must keep the edge the hand drew, or the restore would hand
   //--- back the position the mode had already travelled to.
   if(prev == BOXEXT_OFF && ext != BOXEXT_OFF) BoxEdgeRemember(name);
   BoxMarkWrite(name, mid, ext, n);
   //--- P-UI-132: leaving the ON states by the «…» cycle is a disarm too, so it gives
   //--- the edge back on the same terms as the strip cell's OFF (one memo, spent once).
   if(ext == BOXEXT_OFF) BoxEdgeRestore(name);
   return ext;
}
string BoxExtText(const string name)
{
   bool mid = false; int ext = BOXEXT_OFF, n = 0;
   BoxMarkRead(name, mid, ext, n);
   if(ext == BOXEXT_TOUCH) return "Extend: to touch";
   if(ext == BOXEXT_END) return "Extend: to end";
   if(ext == BOXEXT_NBARS) return "Extend: " + IntegerToString(n) + " bars";
   return "Extend: off";
}
//--- one new-bar step for a marked box: the LATER edge travels to the forming
//--- bar. TOUCH stops at the first closed bar whose range meets the box;
//--- NBARS counts down and clears itself. The mid line rides along.
bool BoxExtendStep(const string name)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   if(DrawObjectType(name) != OBJ_RECTANGLE) return false;
   bool mid = false; int ext = BOXEXT_OFF, n = 0;
   BoxMarkRead(name, mid, ext, n);
   if(ext == BOXEXT_OFF) return false;
   datetime t0 = 0, t1 = 0; double p0 = 0.0, p1 = 0.0;
   if(!BoxAnchors(name, t0, p0, t1, p1)) return false;
   datetime now = iTime(NULL, 0, 0);
   if(now <= 0) return false;
   int li = (t1 >= t0) ? 1 : 0;
   datetime te = (li == 1) ? t1 : t0;
   if(te < now)
   {
      if(ext == BOXEXT_TOUCH)
      {
         double top = MathMax(p0, p1), bot = MathMin(p0, p1);
         double bh = iHigh(NULL, 0, 1), bl = iLow(NULL, 0, 1);
         if(bl <= top && bh >= bot) { BoxMarkWrite(name, mid, BOXEXT_OFF, 0); return true; }
      }
      ObjectSetInteger(0, name, OBJPROP_TIME, li, now);
      if(ext == BOXEXT_NBARS)
      {
         n--;
         if(n <= 0) BoxMarkWrite(name, mid, BOXEXT_OFF, 0);
         else BoxMarkWrite(name, mid, ext, n);
      }
   }
   if(mid) BoxMidSync(name);
   //--- P-DRAW-64a (2026-09-27): the step moved the box's own edge, so the interior
   //--- gets the same frame the level does — otherwise an extending box with a fill
   //--- wears a stale interior until the pump's next pass. One guarded call per step
   //--- (once a bar), a no-op where no interior lives.
   FillChildSync(name);
   return true;
}
//--- P-ORPHAN-ALL (2026-10-04) — EVERY REMNANT ANSWERS FOR ITSELF, AND SAYS SO.
//--- The pass below carries the repo's three orphan rules (the interior's child, the
//--- box's 50 % line, the fibo pen's rows); «این بقایش چرا حذف نمیشه» was one of them
//--- MISSING rather than one of them wrong (measured 2026-10-04: two deleted fibos had
//--- left 36 `_FSD` rows on the hand's chart — `Fibo 54705` and `Fibo 58985` were gone
//--- from the chart file while their whole pen was still in it). What no rule had was
//--- a WITNESS: a cleanup was invisible, so it could only be believed. One line per
//--- drop, through the ONE deleter — drops are rare, the pass is not, and a stray that
//--- dies now names itself and its missing master in the diag file.
void DrawOrphanDrop(const string nm, const string par)
{
   ObjectDelete(0, nm);
   DrawStripDiagEmit("[drawstrip] ORPHAN drop=\"" + nm + "\" par=\"" + par + "\"");
}
void BoxExtrasPump()
{
   static uint s_bxMs = 0;
   static datetime s_bxBar = 0;
   datetime cb = iTime(NULL, 0, 0);
   bool newBar = (cb != 0 && cb != s_bxBar);
   s_bxBar = cb;
   uint now = GetTickCount();
   if(!newBar && now - s_bxMs < 2000) return;
   s_bxMs = now;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      //--- P-DRAW-64: the interior's children are swept HERE — an orphan (its
      //--- master deleted) or one whose fill went off is dropped in this pass, and
      //--- one whose master moved while nothing was open is re-stamped.
      if(FillIsChild(nm))
      {
         string par = FillChildParent(nm);
         if(par == "" || ObjectFind(0, par) < 0) { DrawOrphanDrop(nm, par); continue; }   // P-ORPHAN-ALL
         //--- P-DRAW-64: a child of an INDICATOR object is a STRAY — an earlier build
         //--- of this split synced any dragged rectangle, the product's own boxes
         //--- included, which moved such a box's interior into a child and left it
         //--- behind on the next drag («من اینو که جابجا میکنم اون یکی جا میمونه»).
         //--- It goes here, and the master's OWN fill comes back with it, because a
         //--- child only ever existed while that fill was on.
         if(DrawIsIndicatorObject(par))
         {
            DrawOrphanDrop(nm, par);   // P-ORPHAN-ALL: a child of an indicator is a stray too
            if((int)ObjectGetInteger(0, par, OBJPROP_FILL) == 0)
               ObjectSetInteger(0, par, OBJPROP_FILL, true);
            continue;
         }
         FillChildSync(par);
         continue;
      }
      if(nm == "" || DrawIsIndicatorObject(nm)) continue;
      //--- P-DRAW-64a (2026-09-27) — THE MID LINE'S OWN ORPHAN RULE. Deleting a box
      //--- that wore its 50 % left the `<box>_BX50` dotted line on the chart FOREVER:
      //--- the pass skipped anything that IS a mid child, and nothing else knew it.
      //--- So the child answers for its own parent here — one parse and one probe per
      //--- 2 s pass, a delete only when the parent is really gone (the interior's own
      //--- sweep is the same rule, one block up).
      if(BoxIsMidChild(nm))
      {
         string par = BoxMidParent(nm);
         if(par == "" || ObjectFind(0, par) < 0) DrawOrphanDrop(nm, par);   // P-ORPHAN-ALL
         continue;
      }
      //--- P-LOOK-RAY2: the pen's children answer for their own parent too (the same
      //--- orphan rule, one family over). A fibo deleted while the indicator was off
      //--- leaves `_FSD/_FSC/_FSW` bands whose master is gone - a styled line drawn on
      //--- nothing is exactly what "strays" means here, and nothing else knew them.
      if(FibPenIsChild(nm) || FibPenFamIsChild(nm))
      {
         string par = FibPenChildParent(nm);
         if(par == "" || ObjectFind(0, par) < 0) DrawOrphanDrop(nm, par);   // P-ORPHAN-ALL
         continue;
      }
      //--- P-DRAW-64: the pass was already paying for ONE type read, so the
      //--- interior's net rides it: a master whose fill is ON (an old build's
      //--- drawing, or one the terminal's own dialog switched back on — the split's
      //--- only silent conflict) and a master that MOVED while nothing was open are
      //--- both re-stamped here. A drawing with no interior costs one probe find.
      int ty = (int)ObjectGetInteger(0, nm, OBJPROP_TYPE);
      if(ty == OBJ_RECTANGLE || ty == OBJ_TRIANGLE || ty == OBJ_ELLIPSE ||
         ty == OBJ_CHANNEL || ty == OBJ_FIBOCHANNEL)
      {
         if(ObjectFind(0, FillChildName(nm)) >= 0 ||
            (int)ObjectGetInteger(0, nm, OBJPROP_FILL) != 0)
            FillChildSync(nm);
      }
      //--- P-LOOK-RAY2 (2026-10-04) - THE PEN'S NET RIDES THE PASS THAT ALREADY PAYS
      //--- THE TYPE READ. The pen had only event paths, so a master the terminal landed
      //--- after the last event kept a stale pen forever (measured: the pen ran x=59..721
      //--- against level lines at x=681..1079 - "the styles are not applied on the right
      //--- side"). `FibPenHeal` is one memo compare while the pen matches the master it
      //--- was built from, and the sync only on a mismatch.
      if(ty == OBJ_FIBO || ty == OBJ_FIBOFAN) FibPenHeal(nm);
      if(ty != OBJ_RECTANGLE) continue;
      //--- P-UI-134: the marks' CENSUS is the store now, not the description. This
      //--- used to skip every rectangle whose text carried no `[BX` — a test of the
      //--- retired format that would have hidden every box the migration has not
      //--- reached yet. One read (which migrates on the way) answers both questions.
      bool mid = false; int ext = BOXEXT_OFF, n = 0;
      BoxMarkRead(nm, mid, ext, n);
      //--- DIAG-136 (2026-10-02) — THE CHART-SIDE HALF OF THE SAME COMPLAINT.
      //--- «باکس اصلا رنگ نمیکره» named the BOX, not the panel, and the panel detector
      //--- (DIAG-135) would have stayed silent on it. Same rare-on-demand shape, so the
      //--- same answer: the pass that ALREADY walks every rectangle every 2 s now asks
      //--- the one question that settles it — does the ink the chart wears equal the ink
      //--- the box's own stored colour says it must wear, and is it any closer to the
      //--- chart background than the colour itself? A border that has blended all the way
      //--- into the background is not «a different colour», it is NO colour — and that is
      //--- the exact shape of «اصلا رنگ نمیکنه».
      //--- GATED ON THE PRODUCT'S OWN TAG: a rectangle with no `[CL…]` was never
      //--- coloured by us and is not ours to judge, so an ordinary hand-drawn box costs
      //--- one `StringFind` and nothing else. One line per DISTINCT signature, as
      //--- DIAG-135, for the same reason — a rare bug must not flood the file.
      BoxInkWitness(nm);
      if(!mid && ext == BOXEXT_OFF) continue;
      if(mid) BoxMidSync(nm);
      if(ext != BOXEXT_OFF && newBar) BoxExtendStep(nm);
   }
}
#endif // DRAW_STRIP_PICK_MQH
// DrawStrip_GearA.mqh - DrawStrip split 2026-09-29: exact lines 2381-3364 of DrawStrip.mqh, byte-identical, zero renames.
#ifndef DRAW_STRIP_GEARA_MQH
#define DRAW_STRIP_GEARA_MQH


// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-13 — THE MORE-POPOVER MODEL. Rows are typed (action vs preset vs
// overflow slot) and rebuilt by ONE builder the layout, the painter and the
// router all read — "which row does what" has exactly one answer.
// ══════════════════════════════════════════════════════════════════════════
//--- P-DRAW-64 — «۵۰ درصد باکس»: THE ONE TAP that fills an interior at half tone.
//--- Its state is exact (interior on AND tone 50), so the row wears a check when
//--- the drawing already is that box; the write itself lives with the tap
//--- (`DrawStripFill50Apply`, after the undo owner).
bool DrawStripFill50IsCur()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   if(DrawSlotRead(s_dsObj, DRAW_SLOT_FILL) < 0.5) return false;
   return (DrawSlotAlphaGet(s_dsObj, DRAW_SLOT_FILLCLR) == DSTRIP_FILL50_TONE);
}
//--- P-DRAW-64 — AN INTERIOR EDIT TURNS THE INTERIOR ON. Choosing the fill's
//--- colour or dragging its bar is a statement about a fill the user expects to
//--- see; with the interior OFF the choice is invisible and reads as "nothing
//--- happened". The same reason `Fill 50%` sets both.
void DrawStripFillShow(const string nm)
{
   if(nm == "" || ObjectFind(0, nm) < 0) return;
   EDrawKind k = DrawKindOf(nm);
   if(!DrawSlotAvailable(k, DRAW_SLOT_FILLCLR)) return;
   if(DrawSlotAvailable(k, DRAW_SLOT_FILL) && DrawSlotRead(nm, DRAW_SLOT_FILL) < 0.5)
      DrawSlotWrite(nm, DRAW_SLOT_FILL, 1.0);
}
//--- the group face of the rule above (the held drawing when there is no group).
void DrawStripFillShowGroup()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return;
   DrawSelPrune();
   int n = DrawSelCount();
   if(n <= 0) { DrawStripFillShow(s_dsObj); return; }
   for(int i = 0; i < n; i++) DrawStripFillShow(DrawSelAt(i));
}
void DrawStripFill50On(const string nm)
{
   if(nm == "" || ObjectFind(0, nm) < 0) return;
   EDrawKind k = DrawKindOf(nm);
   if(!DrawSlotAvailable(k, DRAW_SLOT_FILLCLR)) return;
   if(DrawSlotAvailable(k, DRAW_SLOT_FILL)) DrawSlotWrite(nm, DRAW_SLOT_FILL, 1.0);
   DrawSlotOpacitySet(nm, DSTRIP_FILL50_TONE, DRAW_SLOT_FILLCLR);
}

void DrawStripMoreBuild()
{
   s_dsPN = 0;
   if(s_dsKind == DK_NONE || s_dsObj == "") return;
   EDrawKind k = s_dsKind;
   int r = 0;
   // 1. group apply-all (the retired ALL cell's seat, accent-styled, no icon)
   s_dsMoreKind[r] = DSTRIP_MK_APPLYALL; s_dsMoreArg[r] = 0; r++;
   // 2. templates: every preset + save (the retired TPL/SAVE seats)
   //--- P-DRAW-76: the arg is the SLOT ID, never a position in the list. A cleared template
   //--- leaves a hole (the store keeps the user's numbering), and a position would point at
   //--- that hole and hide the template standing behind it.
   for(int i = 0; i < DRAW_PRESET_MAX && r < DSTRIP_PICK_MAX; i++)
   { if(DrawPresetName(k, i) == "") continue; s_dsMoreKind[r] = DSTRIP_MK_PRESET; s_dsMoreArg[r] = i; r++; }
   if(r < DSTRIP_PICK_MAX) { s_dsMoreKind[r] = DSTRIP_MK_SAVE; s_dsMoreArg[r] = 0; r++; }
   // 3. edit: duplicate + undo
   if(r < DSTRIP_PICK_MAX) { s_dsMoreKind[r] = DSTRIP_MK_DUPE; s_dsMoreArg[r] = 0; r++; }
   if(r < DSTRIP_PICK_MAX) { s_dsMoreKind[r] = DSTRIP_MK_UNDO; s_dsMoreArg[r] = 0; r++; }
   // P-DRAW-21/22: box extras ride the more-popover (the quick row is full for
   // rect: colour/width/style/fill/lock/back) — toggle + cycle, state in text.
   if(k == DK_RECT)
   {
      if(r < DSTRIP_PICK_MAX) { s_dsMoreKind[r] = DSTRIP_MK_BOX50; s_dsMoreArg[r] = 0; r++; }
      if(r < DSTRIP_PICK_MAX) { s_dsMoreKind[r] = DSTRIP_MK_BOXEXT; s_dsMoreArg[r] = 0; r++; }
   }
   //--- P-DRAW-64: the half-filled interior, for every kind that HAS one.
   if(DrawKindHasFillBody(k) && r < DSTRIP_PICK_MAX)
   { s_dsMoreKind[r] = DSTRIP_MK_FILL50; s_dsMoreArg[r] = 0; r++; }
   // 4. overflow value slots past the 6-cap (CHANNEL/FIBOCHAN levels)
   int no = DrawStripOverflowCount(k);
   for(int j = 0; j < no && r < DSTRIP_PICK_MAX; j++)
   { s_dsMoreKind[r] = DSTRIP_MK_SLOT; s_dsMoreArg[r] = DrawStripOverflowSlotAt(k, j); r++; }
   s_dsPN = r;
}
string DrawStripMoreText(const int r)
{
   if(r < 0 || r >= s_dsPN) return "";
   int kind = s_dsMoreKind[r], arg = s_dsMoreArg[r];
   if(kind == DSTRIP_MK_APPLYALL)
   {
      //--- P-DRAW-09b retired (2026-10-03): the count in this label used to be the
      //--- SELECTION's size, so it promised «all 2 selected» while the act underneath
      //--- reached every drawing of the kind. It now counts the drawings this row will
      //--- really touch — the walk `DrawStyleApplyToKind` performs — so the number and
      //--- the act are the same fact.
      int n = DrawStyleKindCount(s_dsObj);
      return "Apply to all " + DrawKindName(s_dsKind) + (n > 0 ? " (x" + IntegerToString(n) + ")" : "");
   }
   if(kind == DSTRIP_MK_PRESET) return DrawPresetName(s_dsKind, arg);
   if(kind == DSTRIP_MK_SAVE) return "Save current look";
   if(kind == DSTRIP_MK_DUPE) return "Duplicate";
   if(kind == DSTRIP_MK_UNDO) return (s_duValid ? "Undo last look" : "Undo (nothing yet)");
   if(kind == DSTRIP_MK_BOX50) return "Mid 50% line";
   if(kind == DSTRIP_MK_BOXEXT) return BoxExtText(s_dsObj);
   if(kind == DSTRIP_MK_FILL50) return "Fill 50%";
   if(kind == DSTRIP_MK_SLOT) return DrawStripSlotText(s_dsKind, arg, s_dsObj) + " ...";
   return "";
}
string DrawStripMoreRes(const int r)
{
   if(r < 0 || r >= s_dsPN) return "";
   int kind = s_dsMoreKind[r];
   if(kind == DSTRIP_MK_PRESET) return "::Files\\Icons\\gl_template_m.bmp";
   if(kind == DSTRIP_MK_SAVE) return "::Files\\Icons\\gl_plus_m.bmp";
   if(kind == DSTRIP_MK_DUPE) return "::Files\\Icons\\bk_copy.bmp";
   if(kind == DSTRIP_MK_UNDO) return "::Files\\Icons\\bk_undo.bmp";
   if(kind == DSTRIP_MK_BOX50)
   {
      bool mid = false; int ext = BOXEXT_OFF, n = 0;
      BoxMarkRead(s_dsObj, mid, ext, n);
      return (mid ? "::Files\\Icons\\gl_check_m.bmp" : "::Files\\Icons\\bk_levels.bmp");
   }
   if(kind == DSTRIP_MK_BOXEXT) return "::Files\\Icons\\bk_ray1.bmp";
   if(kind == DSTRIP_MK_FILL50)
      return (DrawStripFill50IsCur() ? "::Files\\Icons\\gl_check_m.bmp"
                                     : "::Files\\Icons\\gl_droplet_m.bmp");
   if(kind == DSTRIP_MK_SLOT) return DrawStripIconRes(s_dsMoreArg[r], s_dsObj);
   return "";   // APPLYALL: accent-styled, no icon
}
string DrawStripMoreTip(const int r)
{
   if(r < 0 || r >= s_dsPN) return "";
   int kind = s_dsMoreKind[r], arg = s_dsMoreArg[r];
   string scope = DrawStripTipScope();
   if(kind == DSTRIP_MK_APPLYALL)
      return "This look on EVERY " + DrawKindName(s_dsKind) + " (MT4's dialog is one at a time)";
   if(kind == DSTRIP_MK_PRESET)
      return "Template: " + DrawPresetName(s_dsKind, arg) +
             (DrawPresetIsBuiltin(arg) ? " (built-in)" : " (mine)") +
             " — click to apply the whole look" + scope +
             (DrawPresetIsBuiltin(arg) ? "" : " — Shift+click deletes it");
   if(kind == DSTRIP_MK_SAVE)
      return "Save this look as one of MY templates — the next drawing of this tool wears it";
   if(kind == DSTRIP_MK_DUPE) return "Copy this drawing beside itself (selects the copy)";
   if(kind == DSTRIP_MK_UNDO)
      return (s_duValid ? "Restore the look before the last edit" : "No edit to undo yet");
   if(kind == DSTRIP_MK_BOX50)
      return "A 50% line across this box (MT4 rectangles have none) — click to toggle" + scope;
   if(kind == DSTRIP_MK_BOXEXT)
      return "Push the far edge with new bars: to first touch, to the end, or N bars — click to cycle" + scope;
   if(kind == DSTRIP_MK_FILL50)
      return "Fill this " + DrawKindName(s_dsKind) + " at 50%: the interior ON, its tone at half" +
             " — one click over the fill color and its bar" + scope;
   if(kind == DSTRIP_MK_SLOT)
      return DrawStripSlotTip(s_dsKind, arg, s_dsObj);
   return "";
}
bool DrawStripMoreIsCur(const int r)
{
   if(r < 0 || r >= s_dsPN) return false;
   if(s_dsMoreKind[r] == DSTRIP_MK_PRESET) return (s_dsMoreArg[r] == s_dsTpl[s_dsKind]);
   if(s_dsMoreKind[r] == DSTRIP_MK_BOX50)
   {
      bool mid = false; int ext = BOXEXT_OFF, n = 0;
      BoxMarkRead(s_dsObj, mid, ext, n);
      return mid;
   }
   if(s_dsMoreKind[r] == DSTRIP_MK_BOXEXT)
   {
      bool mid = false; int ext = BOXEXT_OFF, n = 0;
      BoxMarkRead(s_dsObj, mid, ext, n);
      return (ext != BOXEXT_OFF);
   }
   if(s_dsMoreKind[r] == DSTRIP_MK_FILL50) return DrawStripFill50IsCur();
   return false;
}

//--- P-DRAW-117 (2026-10-01) — THE GROUPS, AND THEY ARE ROWS NOW.
//--- The five seats are the same five the tab row offered (same ids, same
//--- conditions, same per-kind memory) — what changed is that a group is a 42px
//--- ROW of the card's own grid: an icon, its name, and the value it currently
//--- holds. The list is built once per layout, and the walk, the paint, the hit
//--- test and the tool all read THIS answer — "which groups does this kind have"
//--- has exactly one owner, the same way the tab list did.
int DrawStripGearGroups()
{
   int n = 0;
   s_dsGearGrp[n + 1] = DSTRIP_GEAR_PAINT; n++;
   s_dsGearGrp[n + 1] = DSTRIP_GEAR_STYLE; n++;
   if(DrawKindHasLevels(s_dsKind)) { s_dsGearGrp[n + 1] = DSTRIP_GEAR_LEVELS; n++; }
   else if(s_dsKind == DK_TEXT || s_dsKind == DK_ARROW) { s_dsGearGrp[n + 1] = DSTRIP_GEAR_MARK; n++; }
   s_dsGearGrp[n + 1] = DSTRIP_GEAR_TPL; n++;
   s_dsGearGrp[n + 1] = DSTRIP_GEAR_STRIP; n++;
   s_dsGearGrp[0] = n;
   if(s_dsGear != 0)
   {
      bool ok = false;
      for(int i = 1; i <= n; i++) if(s_dsGearGrp[i] == s_dsGear) ok = true;
      if(!ok) s_dsGear = s_dsGearGrp[1];
   }
   return n;
}
string DrawStripGearGroupText(const int gid)
{
   //--- P-DRAW-117: the two look groups wear the word their content is (the old
   //--- `Paint`/`Style` named the retired tab row, not the settings under them).
   if(gid == DSTRIP_GEAR_PAINT) return "Color";
   if(gid == DSTRIP_GEAR_STYLE) return "Stroke";
   if(gid == DSTRIP_GEAR_LEVELS) return "Levels";
   if(gid == DSTRIP_GEAR_MARK) return (s_dsKind == DK_ARROW ? "Mark" : "Text");
   if(gid == DSTRIP_GEAR_TPL) return "Look";
   if(gid == DSTRIP_GEAR_STRIP) return "Row";
   return "";
}
string DrawStripGearGroupRes(const int gid)
{
   if(gid == DSTRIP_GEAR_PAINT) return "::Files\\Icons\\gl_droplet_m.bmp";
   if(gid == DSTRIP_GEAR_STYLE) return "::Files\\Icons\\bk_w2.bmp";
   if(gid == DSTRIP_GEAR_LEVELS) return "::Files\\Icons\\bk_levels.bmp";
   if(gid == DSTRIP_GEAR_MARK) return "::Files\\Icons\\bk_glyph.bmp";
   if(gid == DSTRIP_GEAR_TPL) return "::Files\\Icons\\gl_template_m.bmp";
   if(gid == DSTRIP_GEAR_STRIP) return "::Files\\Icons\\bk_more.bmp";
   return "";
}
string DrawStripGearGroupTip(const int gid)
{
   string nm = DrawStripGearGroupText(gid);
   if(gid == DSTRIP_GEAR_PAINT)
      return nm + " — the border and the interior; click the group to fold it away";
   if(gid == DSTRIP_GEAR_STYLE)
      return nm + " — width, line style, shape and layer; click to open";
   if(gid == DSTRIP_GEAR_LEVELS)
      return nm + " — which levels the held drawing shows; click to open";
   if(gid == DSTRIP_GEAR_MARK)
      return nm + " — the mark's own face; click to open";
   if(gid == DSTRIP_GEAR_TPL)
      return nm + " — the saved looks of this tool; click to open";
   if(gid == DSTRIP_GEAR_STRIP)
      return nm + " — which cells the strip's quick row shows; click to open";
   return "";
}
bool DrawStripGearGridChips(const int slot, const int count)
{
   int cw = DrawStripGearCellW();   // P-DRAW-99: the chips sit in ONE column
   int cols = (cw + DSTRIP_GEAR_GRID_GAP) / (DSTRIP_GEAR_CHIP + DSTRIP_GEAR_GRID_GAP);
   if(cols < 1) cols = 1;
   for(int i = 0; i < count; i++)
   {
      if(s_dsGGN >= DSTRIP_GRID_MAX) return false;
      int g = s_dsGGN++;
      s_dsGGKind[g] = 1; s_dsGGSlot[g] = slot; s_dsGGArg[g] = i;
      s_dsGGW[g] = DSTRIP_GEAR_CHIP;
      s_dsGGH[g] = DSTRIP_GEAR_CHIP_H;
      s_dsGGX[g] = DSTRIP_GEAR_PAD + (i % cols) * (DSTRIP_GEAR_CHIP + DSTRIP_GEAR_GRID_GAP);
      s_dsGGY[g] = -1;
   }
   return true;
}
//--- P-DRAW-73 (2026-09-28): the ceiling is REPORTED once, not obeyed silently. The
//--- owner returned false and every caller dropped the answer, so a tab that outgrew
//--- DSTRIP_GLIST_MAX lost rows with no trace — and the plate shrank to match, so the
//--- panel looked right and was missing settings. Bounded: one static flag, one line.
//--- P-DRAW-111 (2026-10-01) — A ROW IS PLACED WHERE IT IS DECLARED. The row took no
//--- `y`: the layout stamped the whole run AFTER the content walk
//--- (`s_dsGRY[r] = y + r*42`, DrawStripGearLayout), so on a tab that mixes bands and
//--- rows every row landed BELOW the last band — outside its own band's block range
//--- (`DrawStripGearSection` registers the block start; `DrawStripGearShiftItems`
//--- moves an item by the block whose [from,to) CONTAINS its y).
//--- MEASURED on the Style tab, DK_RECT, narrow y-space (contentTop = 98):
//--- blocks STROKE@98 · LINE STYLE@182 · SHAPE@266 · LAYER@308, contentEnd = 518.
//--- The wide pass splits at block 3 (`DrawStripGearPlace`: 84/336, 168/252, 210/210
//--- — the 210 wins), so every row — including SHAPE's own two, BOXHALF and EXTEND —
//--- sits in [308,518) and is TRANSLATED into column 1 with LAYER, while SHAPE's
//--- caption stays alone in column 0. The screenshot is exactly that: a bare SHAPE
//--- band on the left, and `Extend right` (a SHAPE row) stacked under `LAYER` on the
//--- right. Only Style mixes the two — Paint, Look, Row, Levels and Mark declare
//--- their rows after their last band, so for them the stamp and the cursor are the
//--- same number and the plate does not move a pixel.
bool DrawStripGearRow(const int kind, const int arg, int &y)
{
   if(s_dsGRN >= DSTRIP_GLIST_MAX)
   {
      static bool said = false;
      if(!said)
      {
         said = true;
         Print("[drawstrip] gear row ceiling reached (", DSTRIP_GLIST_MAX,
               ") — a row was dropped; tab=", s_dsGear, " kind=", (int)s_dsKind);
      }
      return false;
   }
   s_dsGRKind[s_dsGRN] = kind; s_dsGRArg[s_dsGRN] = arg;
   s_dsGRY[s_dsGRN] = y;
   s_dsGRN++;
   y += DSTRIP_GEAR_ROW_H;
   return true;
}
//--- stamp row tops for grid cells appended since mark (one block = one call).
void DrawStripGearGridStamp(const int mark, int &y, const int cols)
{
   int n = s_dsGGN - mark;
   int rows = (n + cols - 1) / cols;
   if(rows < 1) rows = 1;
   for(int g = mark; g < s_dsGGN; g++)
   {
      int row = (g - mark) / cols;
      s_dsGGY[g] = y + row * DSTRIP_GEAR_ROW_H;
   }
   y += rows * DSTRIP_GEAR_ROW_H;
}
//--- P-DRAW-118 (2026-10-01) — ONE COLOUR ROLE AS THE CARDS' OWN QUICK ROW.
//--- The row the hand reads is the CARDS' COUNT COLOR strip: the colour this role
//--- holds NOW, then the palette's first row (`QuickPalColor` = `BioPal` = the
//--- board's own row 0), then the `+` that opens the board (the HEX field, the 64
//--- cells, RECENT and opacity). Every cell lands in the SAME grid arrays the paint,
//--- the hit test and the tool walk (`s_dsGG*` + `s_dsGGC`), so the row has ONE
//--- owner, and it is placed by the same stamp a chip grid uses — one y for the lot.
bool DrawStripGearQuickRow(const int slot, int &y)
{
   int mark = s_dsGGN;
   if(s_dsGGN >= DSTRIP_GRID_MAX) return false;
   {
      int g = s_dsGGN++;
      s_dsGGKind[g] = DSTRIP_GRG_PREV;   s_dsGGSlot[g] = slot; s_dsGGArg[g] = -1;
      s_dsGGW[g]  = DSTRIP_GEAR_SWQ_PREV; s_dsGGH[g] = DSTRIP_GEAR_SWQ_CELL;
      s_dsGGX[g]  = DSTRIP_GEAR_PAD;      s_dsGGY[g] = -1;
   }
   int x = DSTRIP_GEAR_PAD + DSTRIP_GEAR_SWQ_PREV + DSTRIP_GEAR_SWQ_GAP;
   for(int qi = 0; qi < DSTRIP_GEAR_SWQ_N; qi++)
   {
      if(s_dsGGN >= DSTRIP_GRID_MAX) return false;
      int g = s_dsGGN++;
      s_dsGGKind[g] = DSTRIP_GRG_SWATCH; s_dsGGSlot[g] = slot; s_dsGGArg[g] = qi;
      s_dsGGW[g]  = DSTRIP_GEAR_SWQ_CELL; s_dsGGH[g] = DSTRIP_GEAR_SWQ_CELL;
      s_dsGGC[g]  = QuickPalColor(qi);    // P-DRAW-24: ONE palette
      s_dsGGX[g]  = x;                    s_dsGGY[g] = -1;
      x += DSTRIP_GEAR_SWQ_CELL + DSTRIP_GEAR_SWQ_GAP;
   }
   if(s_dsGGN >= DSTRIP_GRID_MAX) return false;
   {
      int g = s_dsGGN++;
      s_dsGGKind[g] = DSTRIP_GRG_PLUS;   s_dsGGSlot[g] = slot; s_dsGGArg[g] = -1;
      s_dsGGW[g]  = DSTRIP_GEAR_SWQ_PLUS; s_dsGGH[g] = DSTRIP_GEAR_SWQ_PLUS;
      s_dsGGX[g]  = x;                    s_dsGGY[g] = -1;
   }
   //--- ONE row: the stamp's own pitch with a column count wider than the run, so
   //--- every cell of the strip shares this row's y (P-DRAW-111: a row is placed
   //--- where it is declared, and this one is declared as a single line).
   DrawStripGearGridStamp(mark, y, DSTRIP_GRID_MAX);
   return true;
}
//--- P-LVL-COLOR — ONE LEVEL'S SWATCH, PAINTED. The chip shows the ink that
//--- level wears while it is on the chart, else what adding it would wear (the
//--- slot's color). Same 22x22 seat and same `ri`/`rc` names as the icon it
//--- replaces (no new object, no new destroy path); the hit test's swatch rect
//--- is this seat. Lives here, not in GearB: that file stands at the 1500
//--- ceiling and never grows (contract §7).
bool DrawStripGearLevelSwatch(const int r, const int rx, const int py, bool &dd)
{
   //--- false = not a level row: the caller's own branch paints it. true eats
   //--- the branch (the icon it would paint is what covered the swatch), and the
   //--- faces' own dirt rides `dd` — a handled-but-clean row reports clean.
   if(s_dsGRKind[r] != 4 || !DrawKindHasLevels(s_dsKind)) return false;
   bool cur = DrawStripGearRowIsCur(r);
   string tip = DrawStripGearRowTip(r);
   double lv = DrawStripGearLevelAt(s_dsGRArg[r]);
   int li = (MathIsValidNumber(lv) ? DrawStripLevelFind(s_dsObj, lv) : -1);
   color lc = (li >= 0 ? (color)(int)ObjectGetInteger(0, s_dsObj, OBJPROP_LEVELCOLOR, li)
                       : (color)(int)DrawSlotRead(s_dsObj, DRAW_SLOT_COLOR));
   string ltip = tip + " · swatch sets this level's color";
   dd |= DrawStripFace(DrawStripRowChipName(r), rx + DSTRIP_GEAR_PAD, py + DSTRIP_CARD_CHIP_Y, 22, 22,
                       cur ? "::Files\\Icons\\pnl_chip_gold.bmp" : "::Files\\Icons\\pnl_chip.bmp", ltip);
   dd |= DrawStripBtn(DrawStripRowIconName(r), rx + DSTRIP_GEAR_PAD, py + DSTRIP_CARD_CHIP_Y, 22, 22,
                      lc, DrawStripInkOn(lc), BioSwatchBorder(lc, BIO_CLR_CARD), "", ltip);
   return true;
}
//--- P-LVL-TEXT — ONE LEVEL'S WORDS. Value plus the level's own note ("50 · TP1").
//--- A note that only repeats the value (MT4's own default) is not shown twice.
//--- Lives here, not in GearB: that file stands at the 1500 ceiling (contract §7).
string DrawStripGearLevelText(const int arg)
{
   double v = DrawStripGearLevelAt(arg);
   if(!MathIsValidNumber(v)) return "";
   string t = DrawStripLevelName(v);
   int li = DrawStripLevelFind(s_dsObj, v);
   if(li >= 0)
   {
      string d = ObjectGetString(0, s_dsObj, OBJPROP_LEVELTEXT, li);
      StringTrimLeft(d); StringTrimRight(d);
      //--- a default text that IS the value ("0.5", "50") is not shown twice:
      //--- numeric-only notes compare by worth, real words always show.
      bool num = (d != "");
      for(int ci = 0; num && ci < StringLen(d); ci++)
      {
         ushort ch = StringGetCharacter(d, ci);
         if((ch < '0' || ch > '9') && ch != '.' && ch != '-' && ch != '+') num = false;
      }
      if(num && DrawStripLevelNorm(StringToDouble(d)) == DrawStripLevelNorm(v)) d = "";
      if(d != "" && d != t) t += " · " + d;
   }
   return t;
}
void DrawStripGearSection(const string text, int &y)
{
   if(s_dsGearSecN < DSTRIP_GEAR_SECTION_MAX)
   {
      s_dsGearSecY[s_dsGearSecN] = y;
      s_dsGearSecCol[s_dsGearSecN] = 0;
      s_dsGearSecText[s_dsGearSecN] = text;
      s_dsGearSecCX[s_dsGearSecN] = -1;   // P-DRAW-66: its own band, no control
      s_dsGearSecN++;
   }
   // P-DRAW-30: a section OPENS A BLOCK — "this header and the content under it"
   // is the unit the wide rule balances, so a header can never be separated from
   // what it labels (the cards' own band rule, PnlRowFull).
   if(s_dsGearBlkN < DSTRIP_GEAR_BLK_MAX) s_dsGearBlkY[s_dsGearBlkN++] = y;
   y += DSTRIP_GEAR_ROW_H;
}
//--- P-DRAW-66 — A CAPTION AND ITS CONTROL ON ONE ROW (C-05). The retired shape
//--- spent TWO bands per setting — a caption band (42) and a control row (42) — so
//--- the Paint tab's three settings cost 252px. This registers the caption on the
//--- row the control then occupies: three settings, 126px, and the card 426 -> 342
//--- (both on the plate law: 48 + 42k).
void DrawStripGearCaptionIn(const string text, const int ctlX, int &y)
{
   if(s_dsGearSecN < DSTRIP_GEAR_SECTION_MAX)
   {
      s_dsGearSecY[s_dsGearSecN] = y;
      s_dsGearSecCol[s_dsGearSecN] = 0;
      s_dsGearSecText[s_dsGearSecN] = text;
      s_dsGearSecCX[s_dsGearSecN] = ctlX;
      s_dsGearSecN++;
   }
   if(s_dsGearBlkN < DSTRIP_GEAR_BLK_MAX) s_dsGearBlkY[s_dsGearBlkN++] = y;
}

//--- P-DRAW-75 (2026-09-28) — A ROW LABEL'S SEAT IS MEASURED, NOT GUESSED. The
//--- Paint tab's two hex fields sat at a fixed 96 written as "12 x 8", but a row
//--- label DRAWS at pt 9 and "COLOR" is 46px: 40px of dead air opened between each
//--- label and its own field, and the band rule was left as a 26px STUB inside it
//--- (LEVEL 90 no. 4 — a hairline carrying no information; B-06/B-07, a real pad).
int DrawStripGearCapW()
{
   int w = PnlTextW("COLOR", DSTRIP_GEAR_LBL_PT);
   int f = PnlTextW("FILL",  DSTRIP_GEAR_LBL_PT);
   if(f > w) w = f;
   //--- P-DRAW-83: the seat is measured FROM THE CAPTION'S OWN X, which is where
   //--- `DrawStripGearSectionsPaint` writes the label (`DSTRIP_GEAR_CAP_X`) — the
   //--- old `w + DSTRIP_ROW_GAP` counted the label's width and forgot the 30px of
   //--- seat the label itself occupies, so the field was placed inside the caption.
   int seat = DSTRIP_GEAR_CAP_X + w + DSTRIP_ROW_GAP;
   return (seat < DSTRIP_PAD) ? DSTRIP_PAD : seat;
}

//--- P-DRAW-74: the panel's content box AFTER the wide pass — the one width the tab
//--- row and the foot centre on. It stood written twice, 32 apart: the tabs asked
//--- `s_dsGearW - 2*PAD` (280) and the foot `s_dsGearW0 - 2*PAD` (312, the PLATE's
//--- inner box), so the foot sat on a rail of its own (H-06). The NARROW build
//--- column below is a different fact and keeps its own constant.
int DrawStripGearColW() { return s_dsGearW - 2 * DSTRIP_GEAR_PAD; }

//--- P-DRAW-99 (2026-09-30) — ONE COLUMN'S OWN CELL, AND IT IS NOT THE BOX.
//--- `DrawStripGearColW()` above is the tab's WHOLE content box: 280 on a 312 tab,
//--- 592 on a 624 one. A 624 tab is TWO columns, not one wide column — the wide pass
//--- walks whole blocks into column 1 at a `DSTRIP_GEAR_COL` (312) pitch, so each
//--- column is 280 wide with a 32px gutter, and 312 + 280 = 592 closes the box
//--- exactly. So "how wide is ONE column" is `280` on every tab, and two readers
//--- were asking the BOX instead and getting two different wrong answers:
//---   * `DrawStripGearResizeEdits` (this file) re-measured a moved field against
//---     592, so the Levels tab's `add a level` was an OBJ_EDIT 592 wide starting at
//---     `px + 312` — its right edge `s_dsGEX+920` against a card that ends at
//---     `s_dsGEX+624`: 296px of live text field painted over the chart.
//---   * `DrawStripGearHit` (DrawStrip_Base) probed a list row 592 wide while
//---     `DrawStripGearPaint` gave that same row a 280 cell, so 312px of bare plate
//---     to the right of the row acted as the row (a click on nothing toggled a
//---     switch). P-DRAW-90 had already made the FOOT ask `DrawStripGearColW()` and
//---     named this exact hazard in the comment above it; the rows were the two
//---     readers it did not reach.
//--- ONE owner here, read by the field, the row, the chip column and the hit test.
//--- The narrow tab's answer is unchanged at 280, so no narrow paint moves a pixel.
int DrawStripGearCellW() { return DSTRIP_GEAR_W - 2 * DSTRIP_GEAR_PAD; }

//--- P-DRAW-30: THE TAB'S CONTENT, built in the NARROW column's own y-space (the
//--- one every block metric above was written for). The wide pass below never
//--- re-derives a block, it TRANSLATES whole blocks into a second column.
void DrawStripGearContent(int &y, bool &levelEdit)
{
   int cw = DrawStripGearCellW();   // P-DRAW-99: ONE column's cell, the owner
   EDrawKind k = s_dsKind;
   int chipCols = (cw + DSTRIP_GEAR_GRID_GAP) / (DSTRIP_GEAR_CHIP + DSTRIP_GEAR_GRID_GAP);
   //--- P-DRAW-117 (2026-10-01) — THE PANEL IS AN ACCORDION, AND THE GROUP LIST
   //--- BRACKETS THE OPEN GROUP. The headers above the open one are laid out, then
   //--- that group's own settings (the chain below, unchanged), then the headers
   //--- BELOW it — so the open group's rows stand directly under their own header
   //--- and every other group is one row away, in reading order.
   //--- Each header OPENS A BLOCK (`DrawStripGearSection`'s own law, P-DRAW-30): "this
   //--- group and the content under it" is the unit the wide pass balances, so a
   //--- header can never be translated away from the settings it names.
   int ng = DrawStripGearGroups();
   int navAt = 0;
   for(int gn = 0; gn < ng; gn++) if(s_dsGearGrp[gn + 1] == s_dsGear) navAt = gn;
   for(int gb = 0; gb <= navAt; gb++)
   {
      if(s_dsGearBlkN < DSTRIP_GEAR_BLK_MAX) s_dsGearBlkY[s_dsGearBlkN++] = y;
      if(!DrawStripGearRow(DSTRIP_GRK_GROUP, s_dsGearGrp[gb + 1], y)) return;
   }
   //--- a FOLDED group is the list alone: the body is asked for the one id no group
   //--- can have, so every branch below declines without a second fence (Touch rule
   //--- 4: the list is still painted — this is not an early return).
   int gOpen = s_dsGearCollapsed ? -1 : s_dsGear;
   if(gOpen == DSTRIP_GEAR_PAINT)
   {
      // P-DRAW-44 (2026-09-25) — NO COLOUR GRID HERE. User order: «رنگ و تنظیماتِ
      // استریپ روی همان دو مالکِ کارتها سوار شود». The popover's 60-swatch Material
      // grid is this project's ONE picker (P-DRAW-39) and this tab's 16 was its
      // duplicate — the open item the audit record kept as row 13. HEX stays: an
      // exact value typed by hand exists nowhere else.
      //--- P-DRAW-64: TWO COLOUR FIELDS, because the drawing wears two colours
      //--- now — `e0` is the BORDER's (`[CL…]`) and `e4` the FILL's (`[FL…]`), the
      //--- same two the strip's own cells own. Typing either is the exact-value
      //--- path the palette cannot offer.
      //--- P-DRAW-75: both fields take the ONE measured label seat, so they align on
      //--- the same x without a guessed 96.
      //--- P-DRAW-117: THE BAND IS GONE — the group's own header row carries the
      //--- word "Color" and its hex, so a COLORS band above COLOR/FILL was the same
      //--- name twice (and 42px of plate for it). A band survives only where it
      //--- labels settings the group's name does not: the Style group's STROKE /
      //--- LINE STYLE / SHAPE / LAYER, and the text group's CAPTION / SIZE.
      //--- P-DRAW-118 (2026-10-01): THE TWO HEX BOXES ARE GONE. The user's order:
      //--- «این color fill از همین جا بشه رنگها شو تغییر داد ... کد رنگ چیکارش کنم»
      //--- — and the answer is the cards' own: a colour is a SWATCH. Each role is a
      //--- band (the cards' caption line) + the quick row under it, and the exact
      //--- value lives where it always lived for a precise hand: the board's HEX
      //--- field, behind the row's `+`. Two surfaces, one colour each, and the
      //--- panel keeps no second face for either (P-DRAW-44's own ruling, one step
      //--- further: the box was the LAST duplicate the group still carried).
      DrawStripGearSection("BORDER", y);
      DrawStripGearQuickRow(DRAW_SLOT_COLOR, y);
      if(DrawSlotAvailable(k, DRAW_SLOT_FILLCLR))
      {
         DrawStripGearSection("FILL", y);
         DrawStripGearQuickRow(DRAW_SLOT_FILLCLR, y);
      }
      // P-DRAW-65: the interior is the FILL's own switch, so it stands on the tab
      // that owns the two colour seats — one value, one home.
      //--- P-DRAW-73 (2026-09-28): on the SHARED row, like COLOR and FILL. It wore
      //--- a band of its own for a single member — 42px of plate for one label and a
      //--- "1" pill, which is why the Paint tab read 342 instead of 300.
      //--- P-DRAW-74: the caption and its control are ONE registration now. The label
      //--- was written unconditionally and the switch behind `DrawSlotAvailable`, so a
      //--- line (no interior) got a labelled row with nothing in it and a 42px plate
      //--- to prove it (C-04: a control that cannot act is not shown).
      //--- P-DRAW-75: the CAPTION IS GONE. The row already names its own feature
      //--- (P-DRAW-68: "Interior" beside a switch that says on/off), so a caption
      //--- reading DRAWING beside it was a second name for one value (LEVEL 90
      //--- no. 20/22) plus a gold dot and a rule around nothing. One name.
      if(DrawSlotAvailable(k, DRAW_SLOT_FILL))
         DrawStripGearRow(1, DRAW_SLOT_FILL, y);
   }
   else if(gOpen == DSTRIP_GEAR_STYLE)
   {
      DrawStripGearSection("STROKE", y);
      int mark = s_dsGGN;
      DrawStripGearGridChips(DRAW_SLOT_WIDTH, 5);
      DrawStripGearGridStamp(mark, y, chipCols);
      DrawStripGearSection("LINE STYLE", y);
      mark = s_dsGGN;
      DrawStripGearGridChips(DRAW_SLOT_STYLE, 5);
      DrawStripGearGridStamp(mark, y, chipCols);
      if(DrawSlotAvailable(k, DRAW_SLOT_RAY))
      {
         DrawStripGearSection("RAY", y);
         mark = s_dsGGN;
         DrawStripGearGridChips(DRAW_SLOT_RAY, 4);
         DrawStripGearGridStamp(mark, y, chipCols);
      }
      DrawStripGearSection("SHAPE", y);
      //--- P-DRAW-64a: the strip's two cells are switches of the DRAWING's own
      //--- geometry, so they stand together — one value, two surfaces.
      if(DrawStripSeatAvail(k, DRAW_SLOT_BOXHALF)) DrawStripGearRow(1, DRAW_SLOT_BOXHALF, y);
      if(DrawSlotAvailable(k, DRAW_SLOT_EXTEND))      DrawStripGearRow(1, DRAW_SLOT_EXTEND, y);
      DrawStripGearSection("LAYER", y);
      DrawStripGearRow(1, DRAW_SLOT_LOCK, y);
      DrawStripGearRow(1, DRAW_SLOT_BACK, y);
   }
   else if(gOpen == DSTRIP_GEAR_LEVELS)
   {
      int nl = DrawStripGearLevelCount();
      //--- P-DRAW-73: a refused row STOPS the loop, so what is left is a prefix of the
      //--- list and the owner has already named the loss in the log.
      //--- P-DRAW-104: BUT THE TWO MANAGEMENT ROWS ARE NOT PART OF THAT BUDGET. The
      //--- loop below ran to `nl` — up to `DSTRIP_GLIST_MAX` (16), because
      //--- `DrawStripGearLevelCount` caps the LIST at the same 16 the ROW array holds
      //--- — and the two rows after it (`All levels on` / `No levels`) were then
      //--- refused by the very same ceiling. So at 9 common + 7 custom levels the two
      //--- rows that are the ONLY way to clear the level set in one gesture were
      //--- simply not built, and the only trace was the one-shot log line: the user
      //--- lost the ability to turn the fibo's levels off and had to delete them one
      //--- at a time. The list is the elastic half; reserve its two seats here, where
      //--- the two mandatory rows are known, rather than raise the array for every
      //--- tab (the other three tabs build at most 12). Nothing is dropped: a level
      //--- past the reserve is simply not LISTED, and the drawing keeps it.
      //--- P-DRAW-117: AND THE GROUP LIST'S OWN HEADERS ARE SPENT SEATS. The list
      //--- rides the same row array as the headers, so `room` reserves what is
      //--- already standing (the headers above AND below this group) as well as the
      //--- two management rows — the P-DRAW-104 defect (a row refused by a ceiling
      //--- nobody re-derived) re-opened in the new shape.
      int room = DSTRIP_GLIST_MAX - 2 - s_dsGRN;   // the two rows below are not optional
      if(room < 0) room = 0;
      for(int i = 0; i < nl && i < room; i++)
      {
         //--- P-DRAW-117: a long list opens a block every DSTRIP_GEAR_LVLBLK rows,
         //--- so the wide pass can split INSIDE the list (P-DRAW-30's own complaint:
         //--- a 20-level fibo must not grow one tower) while no header moves away
         //--- from its content — a header only ever opens a block at a row boundary.
         if((i % DSTRIP_GEAR_LVLBLK) == 0 && s_dsGearBlkN < DSTRIP_GEAR_BLK_MAX)
            s_dsGearBlkY[s_dsGearBlkN++] = y;
         if(!DrawStripGearRow(4, i, y)) break;
      }
      DrawStripGearRow(5, 0, y);
      DrawStripGearRow(5, 1, y);
      levelEdit = true;
   }
   else if(gOpen == DSTRIP_GEAR_MARK)
   {
      if(k == DK_TEXT)
      {
         DrawStripGearSection("CAPTION", y);
         s_dsGearEditY[2] = y; y += DSTRIP_GEAR_ROW_H;
         DrawStripGearSection("SIZE", y);
         int mark = s_dsGGN;
         DrawStripGearGridChips(DRAW_SLOT_FONT, DrawStripFontCount());
         DrawStripGearGridStamp(mark, y, chipCols);
      }
      else
      {
         for(int g = 0; g < DrawStripGlyphCount(); g++)
            if(!DrawStripGearRow(8, DRAW_SLOT_GLYPH * 256 + g, y)) break;
      }
   }
   else if(gOpen == DSTRIP_GEAR_TPL)
   {
      //--- P-DRAW-76: slot ids (see the more-popover's builder) — a hole never shifts the list.
      for(int i = 0; i < DRAW_PRESET_MAX; i++)
      { if(DrawPresetName(k, i) == "") continue; if(!DrawStripGearRow(2, i, y)) break; }
      DrawStripGearRow(3, 0, y);
      DrawStripGearRow(7, 0, y);
   }
   else if(gOpen == DSTRIP_GEAR_STRIP)
   {
      for(int s = 0; s < DRAW_SLOT_N; s++)
      {
         if(s == DRAW_SLOT_MORE) continue;
         if(!DrawSlotAvailable(k, s)) continue;
         if(!DrawStripGearRow(6, s, y)) break;
      }
      if(DrawKindHasLevels(k)) DrawStripGearRow(6, DRAW_SLOT_MORE, y);
      DrawStripGearRow(5, 2, y);
   }
   //--- P-DRAW-117: the groups BELOW the open one close the accordion.
   for(int ga = navAt + 1; ga < ng; ga++)
   {
      if(s_dsGearBlkN < DSTRIP_GEAR_BLK_MAX) s_dsGearBlkY[s_dsGearBlkN++] = y;
      if(!DrawStripGearRow(DSTRIP_GRK_GROUP, s_dsGearGrp[ga + 1], y)) return;
   }
}
//--- P-DRAW-30: move every item whose y sits inside one block into its column.
//--- Grids carry their own X (the colour hover hit test reads it back), so their
//--- column shift is baked here; rows, sections and edits keep a column index the
//--- painter adds. Membership by Y is exact: every block boundary and every item
//--- in a block sits on the same 42px grid the content was built on.
void DrawStripGearShiftItems(const int yFrom, const int yTo, const int shift, const int col)
{
   for(int r = 0; r < s_dsGRN; r++)
      if(s_dsGRY[r] >= yFrom && s_dsGRY[r] < yTo)
      { s_dsGRY[r] += shift; s_dsGRCol[r] = col; }
   for(int g = 0; g < s_dsGGN; g++)
      if(s_dsGGY[g] >= yFrom && s_dsGGY[g] < yTo)
      { s_dsGGY[g] += shift; s_dsGGX[g] += col * DSTRIP_GEAR_COL; }
   for(int i = 0; i < s_dsGearSecN; i++)
      if(s_dsGearSecY[i] >= yFrom && s_dsGearSecY[i] < yTo)
      { s_dsGearSecY[i] += shift; s_dsGearSecCol[i] = col; }
   for(int e = 0; e < 5; e++)
      if(s_dsGearEditY[e] >= yFrom && s_dsGearEditY[e] < yTo)
      { s_dsGearEditY[e] += shift; s_dsGearEditCol[e] = col; }
}
//--- P-DRAW-30 — THE WIDE PASS. `contentEnd` comes in as the narrow stack's own
//--- bottom and leaves as the two-column stack's, so the plate's height (always
//--- 48 + 42k, the skin's own arithmetic) stays on the grid either way.
//---   * a tab with TWO OR MORE blocks: the block map is the balance, and the
//---     split is the contiguous boundary that minimises the taller column —
//---     reading order is kept column by column, and no header leaves its rows;
//---   * a tab with ONE block (a fibo's level list): there is no boundary to
//---     choose, so the ROW RUN splits at its own middle and the section header
//---     stays at the top of the left column. Without this a 20-level fibo would
//---     still grow one 20-row tower — the very complaint this rule answers.
//--- P-DRAW-82: A FIELD'S WIDTH IS A DERIVED RECT, SO IT IS RE-DERIVED WHEN THE
//--- COLUMN CHANGES. `DrawStripGearContent` measures it against the narrow column
//--- (280) because that is the only width known while the content is still being
//--- built; the wide pass then moves the same field into a 592px BOX holding two
//--- 280 columns. One pass, on the two paths that change the width, and only over
//--- the five edit slots.
//--- P-DRAW-99: AND THE PASS MEASURES THE COLUMN, NOT THE BOX. It asked
//--- `DrawStripGearColW()`, which is the whole 592 content box, so a field the wide
//--- pass had just moved into column 1 was re-measured to 592 - 0 and hung 296px
//--- past the card. One owner, `DrawStripGearCellW()` (280 on every tab), and the
//--- narrow answer is identical.
void DrawStripGearResizeEdits()
{
   int colW = DrawStripGearCellW();
   for(int e = 0; e < 5; e++)
      if(s_dsGearEditY[e] >= 0)
      {
         int seat = s_dsGearEditX[e];
         //--- a clamp to zero would delete the field's own object mid-paint, and
         //--- a field is the only way to type an exact value: if the caption
         //--- leaves no room, the field keeps the WHOLE column rather than none.
         if(seat >= colW) { s_dsGearEditX[e] = 0; seat = 0; }
         if(seat < colW)   s_dsGearEditW[e] = colW - seat;
      }
}

void DrawStripGearPlace(const int contentTop, int &contentEnd)
{
   //--- P-DRAW-91: the reset of `s_dsGearW` MOVED UP to the top of
   //--- DrawStripGearLayout, before the content pass — this was the second writer
   //--- of one value, and it was too late for the first reader. The only write
   //--- left here is the one this pass owns: GROWING the column to 624.
   for(int r = 0; r < s_dsGRN; r++) s_dsGRCol[r] = 0;
   for(int i = 0; i < s_dsGearSecN; i++) s_dsGearSecCol[i] = 0;
   for(int e = 0; e < 5; e++) s_dsGearEditCol[e] = 0;
   //--- P-DRAW-86 (2026-09-29) — A NARROW PLATE MUST FIT THE BAKED CARD SET.
   //--- The guard said "<= 10 content rows stays narrow", but the plate's height is
   //--- `contentEnd + FOOT_H` (48) and `DrawStripGearPlate` builds `cardN = (gh-104)/42`
   //--- from it — so n content rows need card `n + 1`, and `pnl_card<n>.bmp` stops at
   //--- 10 (measured on the files: 174..552 tall, 340 wide). A tab with exactly 10
   //--- content rows therefore stayed NARROW with `cardN = 11`, no bake existed,
   //--- `cardExact` read 0 and the plate fell into the composed W body — whose bake is
   //--- `pnl_cardWtop/mid/bot.bmp` at **652 px**, cropped by MT4 to the 340 the narrow
   //--- plate asked for: a 312px panel drawn as the LEFT HALF of a 624px card.
   //--- MEASURED: log `PLATE tab=1 h=566 w=312 cardN=11 exact=0 narrow=1 -> branch=wide`
   //--- (Style, 10 content rows: 4 bands + 2 chip rows + 4 switches) against
   //--- `pnl_cardWtop.bmp 652 70` and a request of `gw + 28 = 340`. Style is reachable
   //--- on every rectangle/line kind, so the user saw a half-card plate.
   //--- The card set is the law: narrow only while the narrow plate's OWN card exists.
   //--- P-DRAW-117 (2026-10-01): AND THE COUNT IS THE ROWS THEMSELVES NOW. With the
   //--- tab band retired the body starts at the head (`contentTop` = 56) and the
   //--- height is `56 + 42R + 48` = `104 + 42R`, i.e. `cardN = R` — so R rows need
   //--- card R and the ceiling is exactly `DSTRIP_GEAR_WIDE_ROWS` (10) rows, one more
   //--- than the `WIDE_ROWS - 1` the tab build could fit (it carried the tab row as
   //--- its extra cell). Read by this one owner; `tools/check-gear-panel.py` reads the
   //--- expression back out of this line against the bakes on disk.
   if(contentEnd - contentTop <= DSTRIP_GEAR_WIDE_ROWS * DSTRIP_GEAR_ROW_H) return;
   if(s_dsGearBlkN >= 2)
   {
      int split = -1, bestH = 0;
      for(int b = 1; b < s_dsGearBlkN; b++)
      {
         int hL = s_dsGearBlkY[b] - contentTop;
         int hR = contentEnd - s_dsGearBlkY[b];
         int h = (hL > hR ? hL : hR);
         if(split < 0 || h < bestH) { bestH = h; split = b; }
      }
      if(split > 0)
      {
         int top[2];
         top[0] = contentTop; top[1] = contentTop;
         for(int b2 = 0; b2 < s_dsGearBlkN; b2++)
         {
            int from = s_dsGearBlkY[b2];
            int to = (b2 + 1 < s_dsGearBlkN ? s_dsGearBlkY[b2 + 1] : contentEnd);
            int col = (b2 < split ? 0 : 1);
            DrawStripGearShiftItems(from, to, top[col] - from, col);
            top[col] += to - from;
         }
         contentEnd = (top[0] > top[1] ? top[0] : top[1]);
         s_dsGearW = DSTRIP_GEAR_W2;
         DrawStripGearResizeEdits();   // P-DRAW-82: a column just became 592
         return;
      }
   }
   if(s_dsGRN < 4) return;
   int half = (s_dsGRN + 1) / 2;
   if(half < 1 || half >= s_dsGRN) return;
   int splitY = s_dsGRY[half];
   DrawStripGearShiftItems(splitY, contentEnd, contentTop - splitY, 1);
   int hL = splitY - contentTop, hR = contentEnd - splitY;
   contentEnd = contentTop + (hL > hR ? hL : hR);
   s_dsGearW = DSTRIP_GEAR_W2;
   DrawStripGearResizeEdits();   // P-DRAW-82: a column just became 592
}
int DrawStripGearLayout(int y0)
{
   int y = y0;
   s_dsGearHeadY = y0;
   DrawStripGearGroups();   // P-DRAW-117: the group list IS the panel's nav now
   //--- P-DRAW-117 (2026-10-01): THE TAB BAND IS RETIRED, so the panel's first
   //--- cell is the group list's own first row and the body starts at the head's
   //--- bottom edge (56) — one 42px row higher than the tab build. The plate's own
   //--- arithmetic follows: gh = 104 + 42*R with `cardN = R` (DrawStripGearPlate),
   //--- so the narrow ceiling is R <= DSTRIP_GEAR_WIDE_ROWS rows (DrawStripGearPlace).
   y += DSTRIP_GEAR_HEAD_H;
   int contentTop = y;
   s_dsGRN = 0; s_dsGGN = 0; s_dsGearSecN = 0; s_dsGearBlkN = 0;
   for(int e0 = 0; e0 < 5; e0++)
   { s_dsGearEditY[e0] = -1; s_dsGearEditX[e0] = 0; s_dsGearEditW[e0] = 0; }
   //--- P-DRAW-91 (2026-09-30) — THE COLUMN WIDTH IS THIS TAB'S BEFORE ANYTHING
   //--- READS IT. User report: on the Paint tab the COLOR and FILL hex fields ran
   //--- off the card (two dark bars ~312px past the plate's right edge). MEASURED:
   //--- `DrawStripGearContent` writes `s_dsGearEditW[e] = DrawStripGearColW() - capW`
   //--- and `DrawStripGearColW()` is `s_dsGearW - 2*PAD` — but the ONLY reset of
   //--- `s_dsGearW` stood inside `DrawStripGearPlace`, which runs AFTER this call.
   //--- Open a WIDE tab (Style/Row, 624), switch to Paint, and the content measured
   //--- itself against the PREVIOUS tab's 592 while the plate asked for 312: field
   //--- width `592 - capW`, off the card by exactly the 312 that separated the two
   //--- columns. P-DRAW-82 had already made the field ask `DrawStripGearColW()` —
   //--- the missing half is that the number must be THIS tab's from the first
   //--- reader. ONE writer, at the top of the pass, before anything can ask.
   s_dsGearW = DSTRIP_GEAR_W;
   bool levelEdit = false;
   DrawStripGearContent(y, levelEdit);
   //--- P-DRAW-111: the row run is NO LONGER stamped here. `DrawStripGearRow` took the
   //--- content cursor by reference and placed each row where it was declared, so this
   //--- loop would have re-written every y the same way it did before — and that second
   //--- write is the defect: a mixed tab's rows came back to a contiguous run below the
   //--- last band, outside the block that owns their header. The column reset stays
   //--- (DrawStripGearPlace owns the same value and runs on every path).
   for(int r = 0; r < s_dsGRN; r++) s_dsGRCol[r] = 0;
    if(levelEdit)
    {
       s_dsGearEditY[1] = y;
       y += DSTRIP_GEAR_ROW_H;
    }
    //--- P-LVL-TEXT: the armed note field rides below the add field — one full
    //--- row on the plate law, so the tab keeps its height contract.
    if(s_dsGear == DSTRIP_GEAR_LEVELS && DrawStripLvlDescWant())
    {
       s_dsGearEditY[4] = y;
       y += DSTRIP_GEAR_ROW_H;
    }
   if(s_dsGear == DSTRIP_GEAR_TPL && s_dsTplNameArmed)
   {
      s_dsGearEditY[3] = y;
      y += DSTRIP_GEAR_ROW_H;
   }
   int contentEnd = y;
   DrawStripGearPlace(contentTop, contentEnd);
   //--- P-DRAW-117: the tab row owned this pass's tail (`s_dsGearTabX/W` and the
   //--- rail it centred on). With the groups as rows there is no rail to seat: the
   //--- foot is the only thing left to place, and the wide pass has already decided
   //--- the width every reader of it asks.
   s_dsGearFootY = contentEnd;
   y = contentEnd + DSTRIP_GEAR_FOOT_H;
   //--- P-DRAW-78: the height reads the CARDS' law now (56 + n*42 + 48), not the
   //--- retired 48 + 42k skin law — see DSTRIP_GEAR_AIR. A height off that grid
   //--- falls back to the composed W body inside DrawStripGearPlate.
   y += DSTRIP_GEAR_AIR;
   return y;
}

//--- P-DRAW-13: the shell's own widths and positions, in ONE pass: the painter,
//--- the plate's size, the hit test and the grip carry all read these, so
//--- "where a cell is" has exactly one answer. Single row, never wraps:
//--- [grip][badge][<=6 icons][more][gear][pin][del], then the open blocks.
void DrawStripLayout()
{
   DrawStripColorHoverClear();
   DrawStripVisInit();
   EDrawKind k = s_dsKind;
   s_dsN = DrawStripQuickCount(k);
   //--- P-DRAW-66: THE THREE GROUPS. The name's reservation IS its ink (the
   //--- retired `+12` with a 40px floor floated it in a gap of its own), and two
   //--- separators split [identity | values | commands].
   int x = DSTRIP_PAD;
   x += DSTRIP_CELL;                                  // grip
   x += DSTRIP_HEAD_AIR;                              // grip → the name
   s_dsBadgeX = x;
   s_dsBadgeW = PnlTextW(DrawStripTitle(), 9);        // the name's own ink
   x += s_dsBadgeW;
   x += DSTRIP_SEP_AIR;                               // identity | values
   s_dsSepX[0] = x;
   x += DSTRIP_SEP_W + DSTRIP_SEP_AIR;
   for(int i = 0; i < s_dsN; i++)
   {
      if(i > 0) x += DSTRIP_GAP;
      s_dsCX[i] = x;
      s_dsCW[i] = DSTRIP_CELL;
      x += DSTRIP_CELL;
   }
   x += DSTRIP_SEP_AIR;                               // values | commands
   s_dsSepX[1] = x;
   x += DSTRIP_SEP_W + DSTRIP_SEP_AIR;
   for(int a = 0; a < DSTRIP_ACT_N; a++)
   {
      if(a > 0) x += DSTRIP_GAP;
      s_dsActX[a] = x;
      x += DSTRIP_CELL;
   }
   x += DSTRIP_PAD;
   int quickW = x;
   int y = DSTRIP_PAD + DSTRIP_CELL + DSTRIP_GAP;    // first open block's top
   int maxW = quickW;
    //--- popover block (ONE at a time): colour grid, or full-width list rows.
    s_dsPN = 0;
    s_dsPHexY = -1;
    s_dsPHeadY = -1;
    s_dsPRecY = -1;
    s_dsPOpY = -1;s_dsBW = 0; s_dsBH = 0;   // P-DRAW-48: the board's rect exists only for a colour board
   //--- P-PAL-21 (2026-10-02) — THERE IS NO COLOUR BOARD LEFT. `s_dsPicker` cannot
   //--- hold a colour seat since P-PAL-19: a tap on the colour cell asks the CARDS'
   //--- palette (`DrawStripPalAsk`) and nothing writes a colour seat back. So the
   //--- whole `DrawStripIsColorSlot(s_dsPicker)` branch — the grid, the RECENT band,
   //--- the HEX field, the opacity bar, the page seats and the studio — was a layout
   //--- for a plate that no longer exists, and its plate was measured by
   //--- `DrawStripPalLayout` in a file that this build no longer has. The list rows
   //--- below are the picker that is still real (width, style, level, MORE).
   if(s_dsPicker != DSTRIP_PICK_NONE)
   {
      if(s_dsPicker == DSTRIP_MORE) DrawStripMoreBuild();
      int need = 0;
      if(s_dsPicker == DSTRIP_MORE) need = s_dsPN;
      else need = DrawStripPickCount(k, s_dsPicker);
      if(need > DSTRIP_PICK_MAX) need = DSTRIP_PICK_MAX;
      // list width: widest row text + icon seat, capped
      int lw = 0;
      for(int r = 0; r < need; r++)
      {
         string t = DrawStripPopRowText(r);
         int w = PnlTextW(t, 7) + 34;
         if(w > lw) lw = w;
      }
      if(lw < 150) lw = 150;
      if(lw > 280) lw = 280;
      for(int r2 = 0; r2 < need; r2++) s_dsPY[r2] = y + r2 * DSTRIP_PICK_ROW;
      y += need * DSTRIP_PICK_ROW;
      if(lw + 2 * DSTRIP_PAD > maxW) maxW = lw + 2 * DSTRIP_PAD;
      s_dsPN = need;
   }
   //--- P-DRAW-32 (2026-09-24) — THE SETTINGS PANEL IS ITS OWN SURFACE. It used
   //--- to be THIS plate GROWING tall (one window wearing both), so opening
   //--- settings turned the toolbar into a tower. It is laid out in its OWN
   //--- y-space now (0 = the panel plate's own top) and can no longer move
   //--- s_dsW/s_dsH — the strip stays the compact quick row it is, and the two
   //--- rects are placed and carried apart (`DrawStripPlaceGear`).
   s_dsGRN = 0; s_dsGGN = 0;
   s_dsGearH = 0; s_dsGearW0 = 0; s_dsGearHeadY = -1;
   if(s_dsGear != 0)
   {
      s_dsGearH = DrawStripGearLayout(0);
      // P-DRAW-30: the panel's own width, wide (624 + pads) or narrow (312 + pads).
      s_dsGearW0 = s_dsGearW;   // P-DRAW-75: the plate IS the card (312/624), not card+pads
   }
   s_dsW = maxW;
   s_dsH = y - DSTRIP_GAP + DSTRIP_PAD;
   //--- P-PAL-21: the board's placement pass went with the board (a colour seat is
   //--- never the picker now), so the layout ends at the strip's own rect.
}
//--- popover list-row text, one owner for layout and paint.
string DrawStripPopRowText(const int r)
{
   if(s_dsPicker == DSTRIP_MORE) return DrawStripMoreText(r);
   if(s_dsPicker == DSTRIP_SLOT_LEVELS)
   {
      double v = DrawStripGearLevelAt(r);
      return (MathIsValidNumber(v) ? DrawStripLevelName(v) : "");
   }
   return DrawStripPickText(s_dsKind, s_dsPicker, r);
}
string DrawStripPopRowRes(const int r)
{
   if(s_dsPicker == DSTRIP_MORE) return DrawStripMoreRes(r);
   if(s_dsPicker == DRAW_SLOT_WIDTH)
      return "::Files\\Icons\\bk_w" + IntegerToString(r + 1) + ".bmp";
   if(s_dsPicker == DRAW_SLOT_STYLE)
   {
      // P-LOOK: no baked glyphs for looks — each wears its native icon.
      int rr = r;
      if(rr == FIBPEN_STYLE_NEON) rr = 1;
      else if(rr == FIBPEN_STYLE_CAPS || rr == FIBPEN_STYLE_WASH) rr = 0;
      if(rr < 0 || rr > 4) return "";
      return "::Files\\Icons\\bk_style" + IntegerToString(rr) + ".bmp";
   }
   if(s_dsPicker == DRAW_SLOT_RAY)
      return "::Files\\Icons\\bk_ray" + IntegerToString(r) + ".bmp";
   if(s_dsPicker == DRAW_SLOT_FONT) return "::Files\\Icons\\gl_textsize_m.bmp";
   if(s_dsPicker == DRAW_SLOT_GLYPH) return "::Files\\Icons\\bk_glyph.bmp";
   if(s_dsPicker == DSTRIP_SLOT_LEVELS) return "::Files\\Icons\\bk_levels.bmp";
   return "";
}
string DrawStripPopRowTip(const int r)
{
   if(s_dsPicker == DSTRIP_MORE) return DrawStripMoreTip(r);
   if(s_dsPicker == DSTRIP_SLOT_LEVELS)
   {
      double v = DrawStripGearLevelAt(r);
      if(!MathIsValidNumber(v)) return "";
      bool on = (DrawStripLevelFind(s_dsObj, v) >= 0);
      return DrawStripLevelName(v) + (on ? " is on — click to remove" : " — click to add") +
             " (the held drawing)";
   }
   return DrawStripPickTip(s_dsObj, s_dsKind, s_dsPicker, r);
}
bool DrawStripPopRowIsCur(const int r)
{
   if(s_dsPicker == DSTRIP_MORE) return DrawStripMoreIsCur(r);
   if(s_dsPicker == DSTRIP_SLOT_LEVELS)
   {
      double v = DrawStripGearLevelAt(r);
      return (MathIsValidNumber(v) && DrawStripLevelFind(s_dsObj, v) >= 0);
   }
   return DrawStripPickIsCur(s_dsObj, s_dsKind, s_dsPicker, r);
}

void DrawStripClosePicker()
{
   DrawStripColorHoverClear();
   //--- P-PAL-21: the board's chrome prune went with the board (nothing painted it
   //--- any more); `DrawStripSkinPurgeAt(2)` below is what still has a plate to take.
   //--- P-DRAW-75 (2026-09-28): the board's plate (family 2) dies with it, and the
   //--- gate is the PLATE, not a flag — a list popover probes nothing it never made,
   //--- and a plate a path left behind can no longer outlive the state that painted
   //--- it. DrawStripPaint asks the same question and answers it the same way.
   if(ObjectFind(0, DrawStripBoardBgName()) >= 0) DrawStripSkinPurgeAt(2);
   if(s_dsPicker == DSTRIP_PICK_NONE && s_dsPN <= 0) return;
   for(int r = 0; r < DSTRIP_PICK_MAX; r++)
   {
      ObjectDelete(0, DrawStripPickName(r));
      ObjectDelete(0, DrawStripPickIconName(r));
      ObjectDelete(0, DrawStripPickLabelName(r));
      ObjectDelete(0, DrawStripPickChipName(r));
      ObjectDelete(0, DrawStripPickRailName(r));
       ObjectDelete(0, DrawStripPickGlassName(r));   // P-DRAW-33: the glass sheen
    }
    s_dsPicker = DSTRIP_PICK_NONE;
    s_dsPN = 0;
    s_dsPHexY = -1;
    s_dsPHeadY = -1;
    s_dsPRecY = -1;
    s_dsPOpY = -1;
    s_dsOpGrab = false;
    s_dsHexFocus = false;
}
//--- P-DRAW-13: shut the gear panel (tab switch = shut + open).
//--- P-DRAW-77: ONE PREFIX WIPE, not a hand list. The list below could only delete
//--- the names it knew, so every object a previous build had created under a name
//--- this one no longer paints (a retired head chip, a renamed close) survived
//--- every tab switch and every close — which is the report: a second header and a
//--- second close sitting on the chart beside the panel's own, the two mixed. The
//--- plate goes with the wipe and `DrawStripGearPlate` rebuilds it on the next
//--- paint, so nothing is lost and nothing can be stranded. One terminal scan
//--- instead of ~300 ObjectDelete calls.
bool DrawStripGearObjectsPurge()
{
   bool dirty = false;
   //--- One prefix wipe when the panel owned anything: the plate rebuilds on the
   //--- next paint while the panel is open, and stays gone when it is shut.
   //--- P-DRAW-117: the probe is the FAMILY, not one spelling — a chart painted by
   //--- the tab build carries `GT0..GT4`, the `GTrack` bed and the `GU` underline,
   //--- and none of the three is painted by this build any more, so the owner that
   //--- takes the panel down must recognise the OLD names as evidence the family is
   //--- on the chart (Touch rule 2: the rename ships with the sweep).
   if(ObjectFind(0, DrawStripRowName(0)) >= 0 || ObjectFind(0, DrawStripGearBgName()) >= 0
      || ObjectFind(0, "PnlDrawS_Gtop") >= 0 || ObjectFind(0, "PnlDrawS_GT0") >= 0
      || ObjectFind(0, "PnlDrawS_GTrack") >= 0 || ObjectFind(0, "PnlDrawS_GU") >= 0)
   { ObjectsDeleteAll(0, "PnlDrawS_G", -1, -1); dirty = true; return dirty; }
   //--- the requested-tab-room of a chart that predates the accordion: the group
   //--- row is a ROW now (`DrawStripRowName`), so these five are orphans by the same
   //--- ruling as their bed and underline — deleted here so a half-upgraded chart
   //--- cannot keep a second nav under the new one.
   for(int t = 0; t < DSTRIP_GEAR_GRP_MAX; t++)
   {
      string tn = "PnlDrawS_GT" + IntegerToString(t);
      if(ObjectFind(0, tn) >= 0) { ObjectDelete(0, tn); dirty = true; }
   }
   if(ObjectFind(0, "PnlDrawS_GTrack") >= 0)
   { ObjectDelete(0, "PnlDrawS_GTrack"); dirty = true; }
   if(ObjectFind(0, "PnlDrawS_GU") >= 0)
   { ObjectDelete(0, "PnlDrawS_GU"); dirty = true; }
   string hn = DrawStripGearHeadName("TB"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("HR"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("MK"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("MG"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("TT"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("ST"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("VB"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("VT"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("X"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("XB"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   hn = DrawStripGearHeadName("XI"); if(ObjectFind(0, hn) >= 0) { ObjectDelete(0, hn); dirty = true; }
   for(int s = 0; s < DSTRIP_GEAR_SECTION_MAX; s++)
   {
      string sn = DrawStripGearSectionName(s);
      if(ObjectFind(0, sn) >= 0) { ObjectDelete(0, sn); dirty = true; }
      if(ObjectFind(0, sn + "D") >= 0) { ObjectDelete(0, sn + "D"); dirty = true; }
      if(ObjectFind(0, sn + "T") >= 0) { ObjectDelete(0, sn + "T"); dirty = true; }
      if(ObjectFind(0, DrawStripGearSectionLineName(s)) >= 0)
      { ObjectDelete(0, DrawStripGearSectionLineName(s)); dirty = true; }
   }
   for(int g = 0; g < DSTRIP_GRID_MAX; g++)
   {
      if(ObjectFind(0, DrawStripGridName(g)) >= 0)
      { ObjectDelete(0, DrawStripGridName(g)); dirty = true; }
      if(ObjectFind(0, DrawStripGridIconName(g)) >= 0)
      { ObjectDelete(0, DrawStripGridIconName(g)); dirty = true; }
      if(ObjectFind(0, DrawStripGridGlassName(g)) >= 0)
      { ObjectDelete(0, DrawStripGridGlassName(g)); dirty = true; }   // P-DRAW-33
   }
   for(int r = 0; r < DSTRIP_GLIST_MAX; r++)
   {
      if(ObjectFind(0, DrawStripRowName(r)) >= 0)
      { ObjectDelete(0, DrawStripRowName(r)); dirty = true; }
      if(ObjectFind(0, DrawStripRowIconName(r)) >= 0)
      { ObjectDelete(0, DrawStripRowIconName(r)); dirty = true; }
      if(ObjectFind(0, DrawStripRowLabelName(r)) >= 0)
      { ObjectDelete(0, DrawStripRowLabelName(r)); dirty = true; }
      if(ObjectFind(0, DrawStripRowChipName(r)) >= 0)
      { ObjectDelete(0, DrawStripRowChipName(r)); dirty = true; }
      if(ObjectFind(0, DrawStripRowRailName(r)) >= 0)
      { ObjectDelete(0, DrawStripRowRailName(r)); dirty = true; }
      if(ObjectFind(0, DrawStripRowStateName(r)) >= 0)
      { ObjectDelete(0, DrawStripRowStateName(r)); dirty = true; }
      if(ObjectFind(0, DrawStripRowSepName(r)) >= 0)
      { ObjectDelete(0, DrawStripRowSepName(r)); dirty = true; }
      //--- P-DRAW-117: and the group row's own DIGEST — the value its name does not
      //--- carry. A member of the row family, so it is deleted by the row's owner.
      if(ObjectFind(0, DrawStripRowDigestName(r)) >= 0)
      { ObjectDelete(0, DrawStripRowDigestName(r)); dirty = true; }
   }
    for(int f = 0; f < DSTRIP_GEAR_FOOT_N; f++)
    {
      if(ObjectFind(0, DrawStripFootName(f)) >= 0)
      { ObjectDelete(0, DrawStripFootName(f)); dirty = true; }
      if(ObjectFind(0, DrawStripFootSkinName(f)) >= 0)
      { ObjectDelete(0, DrawStripFootSkinName(f)); dirty = true; }
      if(ObjectFind(0, DrawStripFootGlyphName(f)) >= 0)
      { ObjectDelete(0, DrawStripFootGlyphName(f)); dirty = true; }
      if(ObjectFind(0, DrawStripFootLabelName(f)) >= 0)
      { ObjectDelete(0, DrawStripFootLabelName(f)); dirty = true; }
   }
   for(int e = 0; e < 5; e++)
      if(ObjectFind(0, DrawStripEditName(e)) >= 0)
      { ObjectDelete(0, DrawStripEditName(e)); dirty = true; }
   return dirty;
}
//--- P-DRAW-85 (2026-09-29) — A FRESH ATTACH OWNS A CLEAN CHART.
//--- Reported: «جابجا بین تب‌ها می‌شم این‌طوری می‌شه» with a screenshot of ONE card
//--- carrying TWO tabs at once (Style's LINE STYLE / SHAPE / LAYER bands beside the
//--- Look tab's template rows), its head and tab row gone. The section half of that
//--- is the incomplete delete in `DrawStripGearSectionsPaint` — fixed there. The
//--- half no painter can answer is the OTHER writer of these names: the terminal's
//--- object list outlives an instance whose teardown never ran (a crash, a chart
//--- closed under it), and `DrawStripSkinBmp`/`DrawStripBtnZ`/`DrawStripFaceZ` all
//--- decide "create or rewrite?" from `ObjectFind(0, nm) < 0` alone. A name that is
//--- already there IS reused — with whatever TYPE the older build created it, and
//--- MT4 draws a button's text onto a bitmap label by writing properties nobody
//--- reads: an object that exists, answers ObjectFind, and paints NOTHING. There is
//--- no reader of "is this mine?" that a fresh instance can trust, so the ONE that
//--- it can prove is the family prefix: every `PnlDrawS_*` object is this module's
//--- (the plate, the quick row, the popover, the board, the settings panel) and a
//--- fresh instance has opened NONE of them. The contract's own line decides it —
//--- «every created name is deleted by the same surface's destroy» — and the destroy
//--- an attach can prove is the one at attach.
//--- COST: one prefix scan per ATTACH (never per frame, never per tick). One call,
//--- from the entry's OnInit beside the teardown's own `DrawStripClose()`.
void DrawStripSweepStale()
{
   ObjectsDeleteAll(0, "PnlDrawS_", -1, -1);
}
#endif // DRAW_STRIP_GEARA_MQH
// DrawStrip_GearB.mqh - DrawStrip split 2026-09-29: exact lines 3365-4406 of DrawStrip.mqh, byte-identical, zero renames.
#ifndef DRAW_STRIP_GEARB_MQH
#define DRAW_STRIP_GEARB_MQH


//--- P-DRAW-87 (2026-09-29) — NAME THE OBJECT, DON'T GUESS IT. The tab row's bed
//--- showed MT4's default blue face on a green build whose every painted colour
//--- is dark by construction (track #1C222C, plate <= 28,34,44, no blue in the
//--- palette, no blue BMP). A colour that cannot come out of this file's pipeline
//--- is either a foreign object or a rendering the code does not own — and which
//--- of the two decides the fix. So on every panel OPEN (user action: rare,
//--- bounded, never on paint) this walks the chart ONCE and prints every object
//--- whose box touches the tab band, with its type and its stored BGCOLOR. The
//--- next screenshot of a blue bar arrives WITH its name attached.
//--- P-DRAW-112 (2026-10-01) — THE CENSUS WALKS THE WHOLE PANEL, AND A LABEL IS
//--- AN OBJECT WITH A BOX. User report on the Style tab: «تب استایل که میزنم اینطوری
//--- میشه، خود تب و دکمه حذف و غیره دیده نمیشه» — the head (title, version, close),
//--- the tab row, the foot and three of the four band CAPTIONS are gone, while the
//--- chips, the rows, the band dots and the count pills are all there. The census
//--- above could not have answered it: its band was the TAB ROW only, and its
//--- `else continue` threw away OBJ_LABEL — the caption labels, the head title, the
//--- foot words, every one of the missing names. So the band is the panel's own rect
//--- and a label's own text/colour/z is printed with it. Bounded: one walk per panel
//--- OPEN (never per paint), the call site is unchanged.
//--- P-DRAW-123 (2026-10-01) — WHAT THE PAINT DID, BESIDE WHAT THE TERMINAL HOLDS.
//--- The report («این هنوز درست نشده», a shot of the open Stroke tab with the SHAPE
//--- and LAYER captions plus `Behind candles`/`Look`/`Row` painted while both other
//--- band captions, the `50 % line`/`Extend right`/`Lock` names, every chip and the
//--- whole left column were bare) could only be closed by EYE, and that is the cost
//--- this closes: the census answers "what does the chart hold", and it answered it
//--- CORRECTLY for every object the screen did not show in the P-DRAW-120 case. What
//--- was missing is the OTHER half — what the paint INTENDED — in a form a machine can
//--- diff. So while `s_dsDiagArm` is set, the four writers every panel object goes
//--- through (label, face, rect, button) each print one `[dsdiag] EXPECT` line with the
//--- object's own name, role, seat, layer and text, at the moment they place it.
//--- This is the paint's OWN numbers — not a second table recomputed here — so a
//--- divergence is always the terminal's doing.
#ifdef DSTRIP_DIAG
bool s_dsDiagArm = false;   // P-DRAW-123: the dump's own one-paint latch
#endif
void DrawStripDiagExpect(const string nm, const string role, const int x, const int y,
                         const int w, const int h, const int z, const string txt)
{
   #ifdef DSTRIP_DIAG
   if(!s_dsDiagArm) return;
   //--- P-DRAW-126: same line, but through the flushed channel, so the reader
   //--- never has to wait for the terminal's own buffer (see DrawStripDiagEmit).
   DrawStripDiagEmit("[dsdiag] EXPECT obj=" + nm + " role=" + role +
                     " xywh=" + IntegerToString(x) + "," + IntegerToString(y) + "," +
                     IntegerToString(w) + "," + IntegerToString(h) +
                     " z=" + IntegerToString(z) + " txt=\"" + txt + "\"");
   #endif
}

void DrawStripGearTabCensus()
{
   if(s_dsGear == 0 || s_dsGearW0 <= 0) return;
   int bx0 = s_dsGEX, bx1 = s_dsGEX + s_dsGearW0;
   int by0 = s_dsGEY, by1 = s_dsGEY + s_dsGearH;   // P-DRAW-112: the WHOLE plate
   DrawStripDiagEmit("[drawstrip] CENSUS rect=" + IntegerToString(bx0) + "," + IntegerToString(by0) + "," + IntegerToString(s_dsGearW0) + "," + IntegerToString(s_dsGearH) + " chart=" + IntegerToString((int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS)) + "x" + IntegerToString((int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS)));   // P-LOG-7: the frame a corner-bound reader needs
   DrawStripDiagSnapRect(bx0, by0, bx1, by1);   // P-LOG-8: the AFTER walk bounds its NEW scan by it
   int n = ObjectsTotal(0, -1);
   for(int oi = 0; oi < n; oi++)
   {
      string on = ObjectName(0, oi, -1);
      if(on == "") continue;
      //--- P-DRAW-124 (2026-10-01) — THE CENSUS WALKS THE STRIP'S WHOLE FAMILY, NOT
      //--- THE GEAR'S OWN NAMES. P-DRAW-112 scoped it to `PnlDrawS_G*` — "this panel
      //--- only" — and that scope is the one blind spot the live hunt needed: the
      //--- objects that can HIDE this panel's ink are exactly the ones the prefix
      //--- threw away. MEASURED (2026-10-01 18:42:35, the report «این هنوز درست نشده»):
      //--- the chart carried `PnlDrawS_GT0..GT3` / `GTrack` (the RETIRED tab family,
      //--- P-DRAW-117) and `PnlDrawS_GE0/GE4` (the retired fields) — none of them
      //--- this build's, none of them in a census that could answer "who is on top".
      //--- P-LOG-7 (2026-10-01) — NO NAME FILTER AT ALL. P-DRAW-124 widened the net to
      //--- `PnlDrawS_`, which still drops every object that is NOT this family — and a
      //--- cover that hides this panel's ink is, by definition, not this panel's; the
      //--- box test below still bounds the walk to the panel's own rect.
      int oty = (int)ObjectGetInteger(0, on, OBJPROP_TYPE);
      int ox = (int)ObjectGetInteger(0, on, OBJPROP_XDISTANCE);
      int oy = (int)ObjectGetInteger(0, on, OBJPROP_YDISTANCE);
      int ow = 0, oh = 0;
      if(oty == OBJ_BUTTON || oty == OBJ_RECTANGLE_LABEL || oty == OBJ_EDIT)
      {
         ow = (int)ObjectGetInteger(0, on, OBJPROP_XSIZE);
         oh = (int)ObjectGetInteger(0, on, OBJPROP_YSIZE);
      }
      else if(oty == OBJ_BITMAP_LABEL)
      {   //--- P-LOG-6: the OBJECT's own size; the resource table read 0 for the plate.
         ow = DrawStripCensusSize(on, oty, 0); oh = DrawStripCensusSize(on, oty, 1);
      }
      else DrawStripCensusAnyBox(on, oty, ox, oy, ow, oh);   // P-LOG-7/8c: a foreign TYPE too — and a chart object's box is its TIME/PRICE anchors
      //--- P-LOG-6: the box the walk tests is the object's OWN box (see
      //--- DrawStripCensusInPanel) — the plate starts 14px outside this rect.
      if(!DrawStripCensusInPanel(on, oty, ox, oy, bx0, by0, bx1, by1)) continue;
      color bg = (color)ObjectGetInteger(0, on, OBJPROP_BGCOLOR);
      int zz = (int)ObjectGetInteger(0, on, OBJPROP_ZORDER);
      //--- P-DRAW-89: the TRACK's tone, printed. It is the one surface on the tab
      //--- band whose colour is COMPUTED rather than a constant, so it is the one
      //--- that can disagree with the four tabs beside it (measured: they read
      //--- 2892317 and it read -16924895 = 0xFEFDBF21). Reading the value back out
      //--- of the object is the fact; recomputing it here would be the guess.
      //--- P-DRAW-117: the track's tone probe went with the track — the census below
      //--- already prints every object's own `bgcolor`, and the retired `GTrack` is
      //--- not a surface this build paints (it is swept, not measured).
      int tone = -1;
      //--- P-DRAW-112 + P-LOG-5: a caption carries its answer in TEXT and COLOR,
      //--- not in a box — and a BUTTON is captioned too (see DrawStripCensusInk).
      string ink = DrawStripCensusInk(on, oty);
      //--- P-DRAW-120: THE FOUR PROPERTIES THAT DECIDE WHETHER MT4 DRAWS IT AT ALL.
      //--- The census carried xywh + bgcolor + z + the label's ink, and the 2026-10-01
      //--- 15:18 report could not be closed with those: every missing object read
      //--- CORRECT here while the screen showed a bare plate (see DrawStripFaceZ).
      //--- `back` is the layer MT4 draws it in (a background object hides under the
      //--- plate), `fnt` a label's point size (0 draws nothing), `tf` its period mask
      //--- (a LABEL-only property per the contract — OBJ_NO_PERIODS draws nothing) and
      //--- `bmp` the face a bitmap label actually resolved, which is the one thing a
      //--- hot reload can break under a name that still exists. Four reads per object,
      //--- on the panel's OPEN only.
      string bmpf = "";
      if(oty == OBJ_BITMAP_LABEL)
         bmpf = ObjectGetString(0, on, OBJPROP_BMPFILE, 0);
      //--- P-DRAW-124: AND THE ONE NUMBER THE TERMINAL DECIDES ITSELF. Two objects on
      //--- the SAME rung are drawn in the terminal's OWN list order — the index this
      //--- walk is already standing on (`oi`), i.e. the order MT4 holds them in. The
      //--- z decides first, the index decides a tie, so `z` alone can never say which
      //--- of two equal-rung objects the screen shows: BOTH the intruder and the ink
      //--- read the same rung and the same seat, and only the index separates them.
      //--- MEASURED on the 15:18 and 18:42 reports: every hidden object's z/back/fnt
      //--- read CORRECT — the tie is the whole story, and it was the one column the
      //--- census did not carry. `tf` reads 0 for every object of this family, shown
      //--- or not, so a reader must NOT translate it into OBJ_NO_PERIODS. P-DRAW-126:
      DrawStripDiagEmit("[drawstrip] TABCENSUS idx=" + IntegerToString(oi) + " obj=" + on +
            " type=" + IntegerToString(oty) + " xywh=" + IntegerToString(ox) + "," +
            IntegerToString(oy) + "," + IntegerToString(ow) + "," + IntegerToString(oh) +
            " bgcolor=" + IntegerToString((int)bg) + " tone=" + IntegerToString(tone) +
            " z=" + IntegerToString(zz) +
            " back=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_BACK)) +
            " fnt=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_FONTSIZE)) +
            " tf=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_TIMEFRAMES)) +
            " bmp=\"" + bmpf + "\" ink=" + ink +
            " win=" + IntegerToString(ObjectFind(0, on)) +            " corner=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_CORNER)) + " font=\"" + ObjectGetString(0, on, OBJPROP_FONT) + "\" anch=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_ANCHOR)) +
            " xof=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_XOFFSET)) + " yof=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_YOFFSET)) + " bord=" + IntegerToString((int)ObjectGetInteger(0, on, OBJPROP_BORDER_COLOR)));
   // P-LOG-7
      DrawStripDiagSnapAdd(on, ox, oy, ow, oh, zz, (int)ObjectGetInteger(0, on, OBJPROP_BACK));   // P-LOG-8
   }
}
//--- P-DRAW-123: THE DUMP — the paint declares, then the chart answers. Arm, repaint
//--- (the panel's own painter, so the declaration and the census describe ONE state),
//--- disarm, then walk. Called from the two user actions that change the state (panel
//--- open, group open/switch) — the census's own bound — and with the `DSTRIP_DIAG`
//--- line commented out it is the census alone, so the switch turns off without
//--- touching a call site (`#ifdef`: the tree's own idiom — `#if <expr>` is not MQL4).
void DrawStripGearDiagDump()
{
   #ifdef DSTRIP_DIAG
   //--- P-DRAW-125 (2026-10-01) — THE DUMP REPAINTS ONLY WHAT IS OPEN.
   //--- MEASURED (2026-10-01 19:25:07.379): this function is called from
   //--- `DrawStripActTap` on the GEAR button, and that path runs on the CLOSE too —
   //--- `DrawStripGearClose()` sets `s_dsGear = 0` and this call follows. The
   //--- unguarded `DrawStripGearPaint()` below then ran with `s_dsGRN = s_dsGGN =
   //--- s_dsGearSecN = 0` (the layout cannot have built a shut panel): it DELETED
   //--- every grid, section and row object of the panel — and, because the head and
   //--- the foot are painted unconditionally, it left the HEAD and the FOOT of a
   //--- closed panel standing on the chart, drawn from the stale origin. The log
   //--- carries that frame in full: `[dsdiag] EXPECT` for `GHTB..GHXI` and
   //--- `GF0..GF2T` — twenty objects, head then foot, nothing between them.
   //--- The diagnostic must never move a pixel the product would not: one guard on
   //--- the panel's own open fact, and a shut dump is the census alone (which
   //--- returns by itself when `s_dsGear == 0`).
   if(s_dsGear != 0 && s_dsGearH > 0)
   {
      s_dsDiagArm = true; s_dsDiagAfter = 1;   // P-LOG-8: the NEXT paint pass re-walks this name list
      DrawStripGearPaint();
      s_dsDiagArm = false;
   }
   #endif
   DrawStripGearTabCensus();
}

void DrawStripGearClose()
{
   DrawStripColorHoverClear();
   if(s_dsGear == 0 && s_dsGRN <= 0 && s_dsGGN <= 0 && s_dsGearHeadY < 0) return;
   DrawStripGearObjectsPurge();
   s_dsGear = 0; s_dsGRN = 0; s_dsGGN = 0;
   s_dsGearHeadY = -1; s_dsGearSecN = 0;
   s_dsGearPressSpent = false;   // P-DRAW-84: the purge is where a panel's press ends
   s_dsGearPlaced = false; s_dsGearPlacedObj = "";   // P-DRAW-88: next open scores anew
   s_dsTplNameArmed = false;
   s_dsLvlDescArmed = false;   // P-LVL-TEXT: a note edit dies with the panel
}

void DrawStripClose()
{
   // P-PERF-DSC1 (2026-10-12) — SUPPRESS DELETE EVENTS DURING BULK SLOT TEARDOWN.
   // DrawStripClose issues ~60+ individual ObjectDelete calls across the slot loop,
   // action buttons, and picker rows. Without the suppression flag every one fires
   // CHARTEVENT_OBJECT_DELETE → the DrawStrip handler runs CHARTEVENT_OBJECT_DELETE
   // again → DELFLUSH path → ChartRedraw() per object. On a chart with ~1000
   // objects that is ~60 × ~10ms = ~600ms of wasted work inside the teardown of a
   // strip that is already being closed. The suppression flag is the same bool every
   // other bulk-delete path sets (LabelFunctions, EventHandlers, LevelPipeline,
   // ObjectCache, DeleteMenu) — the DrawStrip handler exits early on it, skipping
   // all family-heal work for events that are provably not user gestures.
   g_suppressDeleteEvents = true;
   DrawStripColorHoverClear();
   for(int i = 0; i < DSTRIP_MAX_SLOTS; i++)

   {        ObjectDelete(0, DrawStripObjName(i));
        ObjectDelete(0, DrawStripIconName(i));
        ObjectDelete(0, DrawStripIconName(i) + "C");
        ObjectDelete(0, DrawStripIconName(i) + "S");    // P-DRAW-64a: the colour seat's centre
        ObjectDelete(0, DrawStripIconName(i) + "C2");   // ...and its swatch skin
        ObjectDelete(0, DrawStripIconName(i) + "R");    // P-DRAW-64a2: ...and the merged seat's BORDER bar
   }
   ObjectDelete(0, DrawStripGripName());
   ObjectDelete(0, DrawStripGripIconName());
   ObjectDelete(0, DrawStripGripIconName() + "C");
   ObjectDelete(0, DrawStripBadgeName());
   for(int g = 0; g < 2; g++) ObjectDelete(0, DrawStripSepName(g));   // P-DRAW-66
   for(int a = 0; a < DSTRIP_ACT_N; a++)
   {
      ObjectDelete(0, DrawStripActName(a));
      ObjectDelete(0, DrawStripActIconName(a));
      ObjectDelete(0, DrawStripActIconName(a) + "C");
   }
   for(int r = 0; r < DSTRIP_PICK_MAX; r++)
   {
      ObjectDelete(0, DrawStripPickName(r));
      ObjectDelete(0, DrawStripPickIconName(r));
      ObjectDelete(0, DrawStripPickLabelName(r));
      ObjectDelete(0, DrawStripPickChipName(r));
      ObjectDelete(0, DrawStripPickRailName(r));
      ObjectDelete(0, DrawStripPickGlassName(r));   // P-DRAW-33: the glass sheen
   }
   DrawStripGearClose();
   ObjectDelete(0, DrawStripBgName());
   DrawStripSkinPurge();   // P-DRAW-29: the skin family dies with the strip
   g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
   g_suppressDeleteEvents = false;
   s_dsOpen = false;
   s_dsObj = "";
   s_dsKind = DK_NONE;
   s_dsN = 0;
   DrawStripPublishRect();   // P-DRAW-31: a closed strip occupies no pixels
   DrawStripSurfaceClear();  // P-PAL-20: owns no popup pixels either — the ledger dies with its owner
    s_dsPicker = DSTRIP_PICK_NONE;   // the popover dies with the strip
    s_dsPN = 0;                      // (the recent colours survive: they are the trader's)
    s_dsPHexY = -1;
    s_dsPHeadY = -1;
    s_dsPOpY = -1;
    s_dsOpGrab = false;
    s_dsHexFocus = false;
    //--- P-PAL-21: the board's chrome prune is gone with the board.
   //--- P-DRAW-32: the panel's placement belongs to THIS strip session — a fresh
   //--- open lands the panel beside the plate it serves, never where the last
   //--- strip's hand left it (the free space around a new drawing is new space).
   s_dsGearManual = false;
   s_dsPinned = false;
   DrawStripGripRelease();   // P-UI-113d: a close never leaves the view locked
   DrawStripOpenerDisarm();  // P-UI-113c: nor the opener guard armed
   DrawStripHoldSelectionDisarm();  // P-UI-113g: no close outlives a selection repair
   // P-DRAW-09b: the group belongs to the OPEN strip — a new one takes its own
   // snapshot (the selection may have changed on the chart in between).
   DrawSelClear();
}

//--- P-DRAW-09d: GUARDED WRITES. In MT4 every `ObjectSet*` marks the chart dirty
//--- and the repaint costs what the chart's object count costs (~1000-2500 here),
//--- so a write of a value the object already has is pure loss (P-PERF-02's law).
//--- These two are the strip's whole write path for faces, and both answer
//--- whether a pixel really moved.
bool DrawStripSetInt(const string nm, const int prop, const long v)
{
   if(ObjectGetInteger(0, nm, prop) == v) return false;
   ObjectSetInteger(0, nm, prop, v);
   return true;
}
bool DrawStripSetStr(const string nm, const int prop, const string v)
{
   if(ObjectGetString(0, nm, prop) == v) return false;
   ObjectSetString(0, nm, prop, v);
   return true;
}
//--- the modifier form (bitmap ON/OFF states share one face here).
bool DrawStripSetStr2(const string nm, const int prop, const int mod, const string v)
{
   if(ObjectGetString(0, nm, prop, mod) == v) return false;
   ObjectSetString(0, nm, prop, mod, v);
   return true;
}

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-13 — THREE PAINTERS, EVERY SURFACE. Buttons stay the controls (a
// button stays under its skin, Z_PANEL_BASE/Z_PANEL_SKIN parity); bitmaps are
// faces; labels are left-aligned ink. All guarded, all answering dirty.
// ══════════════════════════════════════════════════════════════════════════
//--- P-DRAW-48 (2026-09-26) — THE PLATE'S OWN BODY RIDES THE PLATE'S Z.
//--- The skin's mid band is a filled button the size of the whole plate and it was
//--- born at Z_STRIP_ICON — the CELLS' z. Equal z is settled by the creation order,
//--- so any repaint that re-created the mid band put it over the board's 64 cells,
//--- its RECENT band and its HEX field (the reported empty board). At Z_STRIP the
//--- plate can never be drawn over its own contents, whatever the order did.
bool DrawStripBtnZ(const string nm, const int x, const int y, const int w, const int h,
                   const color face, const color ink, const color rim,
                   const string txt, const string tip, const int z)
{
   bool dirty = false;
   DrawStripForeign(nm, OBJ_BUTTON);   // P-DRAW-125: a name of another type is not mine
   if(ObjectFind(0, nm) < 0)
   {
      if(!ObjectCreate(0, nm, OBJ_BUTTON, 0, 0, 0)) return false;
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      // P-DRAW-09c: the cells speak the UI's own metric owner (P-UI-34), not a
      // raw point size: MT4 sizes a font at the terminal's DPI, so a literal
      // would draw 25% wider at 125% and overflow the cell.
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, PnlPt(7));
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, z);
      // P-UI-34 (2026-09-25): STATE must be false on birth. MT4 on Windows 11
      // flips a button to its OS "pressed" skin (white/grey) whenever STATE is
      // left at default — the panels' own PnlSetButton does the same init.
      ObjectSetInteger(0, nm, OBJPROP_STATE, false);
      dirty = true;
   }
   dirty |= DrawStripSetInt(nm, OBJPROP_XDISTANCE, x);
   dirty |= DrawStripSetInt(nm, OBJPROP_YDISTANCE, y);
   dirty |= DrawStripSetInt(nm, OBJPROP_XSIZE, w);
   dirty |= DrawStripSetInt(nm, OBJPROP_YSIZE, h);
   dirty |= DrawStripSetInt(nm, OBJPROP_BGCOLOR, face);
   dirty |= DrawStripSetInt(nm, OBJPROP_COLOR, ink);
   dirty |= DrawStripSetInt(nm, OBJPROP_BORDER_COLOR, rim);
   // P-DRAW-48: the z is re-asserted every paint — an object born before this law
   // carries the old one, and a write of the value already there is free.
   dirty |= DrawStripSetInt(nm, OBJPROP_ZORDER, z);
   // P-UI-34: re-assert STATE=false every paint so a click that toggled the
   // button's own state (MT4 toggles STATE on click internally) cannot leave
   // the face white for the next frame.
   dirty |= DrawStripSetInt(nm, OBJPROP_STATE, false);
   dirty |= DrawStripSetStr(nm, OBJPROP_TEXT, txt);
   dirty |= DrawStripSetStr(nm, OBJPROP_TOOLTIP, tip);
   DrawStripDiagExpect(nm, "btn", x, y, w, h, z, txt);
   return dirty;
}
//--- the ordinary cell: the icon layer, above the plate it sits on.
bool DrawStripBtn(const string nm, const int x, const int y, const int w, const int h,
                  const color face, const color ink, const color rim,
                  const string txt, const string tip)
{
   return DrawStripBtnZ(nm, x, y, w, h, face, ink, rim, txt, tip, Z_STRIP_ICON);
}
//--- the icon face, centred in its cell (MT4 paints at native size from the
//--- label's own corner). res == "" deletes the face. Whichever object the
//--- terminal's hover lands on (button or face) carries the same tooltip.
bool DrawStripFaceZ(const string nm, const int x, const int y, const int w, const int h,
                    const string res, const string tip, const int z)
{
   if(res == "")
   {
      if(ObjectFind(0, nm) >= 0) { ObjectDelete(0, nm); return true; }
      return false;
   }
   DrawStripForeign(nm, OBJ_BITMAP_LABEL);   // P-DRAW-125: the type, not the name
   int made = 0;
   if(ObjectFind(0, nm) < 0)
   {
      if(!ObjectCreate(0, nm, OBJ_BITMAP_LABEL, 0, 0, 0)) return false;
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, z);
      made = 1;
   }
   bool dirty = (made > 0);   // P-DRAW-125: a birth IS a change, whatever the defaults read
   //--- P-DRAW-120 (2026-10-01) — THE TWO PROPERTIES THAT DECIDE WHETHER MT4 DRAWS
   //--- THIS FACE ARE RE-ASSERTED EVERY PAINT, NOT ONLY AT BIRTH.
   //--- MEASURED on the 2026-10-01 15:18 shot (EURUSD,M5, src 729d3b567d3dd197): the
   //--- terminal held every object of the open Stroke tab at its right seat with the
   //--- right ink — TABCENSUS read `GR2T "50 % line":14865611 z=1442`, `GS0T
   //--- "STROKE"`, the chip/icon faces, the head, the foot — while the SCREEN showed
   //--- 31 of those 104 (tools/tmp-measure-shot.py), the whole left column, the head
   //--- and the foot bare plate. The
   //--- one difference the painters had between those 21 and the rest: `DrawStripBtnZ`
   //--- re-asserts `OBJPROP_ZORDER` every paint (P-DRAW-48's own law, GearB:213) and
   //--- the FACE and LABEL painters only ever wrote it inside their `ObjectFind < 0`
   //--- block — so a face or a label born under an older rung keeps that rung for the
   //--- life of the object, and equal z is settled by CREATION ORDER (P-DRAW-48), which
   //--- no later build can reach. Same heal, same owner: the write is compare-guarded,
   //--- so a still frame still costs two reads per face and touches nothing.
   dirty |= DrawStripSetInt(nm, OBJPROP_ZORDER, z);
   dirty |= DrawStripSetInt(nm, OBJPROP_BACK, false);
   int pw = DrawStripResW(res), ph = DrawStripResH(res);
   dirty |= DrawStripSetStr(nm, OBJPROP_BMPFILE, res);
   dirty |= DrawStripSetInt(nm, OBJPROP_XDISTANCE, x + (w - pw) / 2);
   dirty |= DrawStripSetInt(nm, OBJPROP_YDISTANCE, y + (h - ph) / 2);
   dirty |= DrawStripSetStr(nm, OBJPROP_TOOLTIP, tip);
   DrawStripDiagExpect(nm, "bmp", x, y, w, h, z, res);
   return dirty;
}
bool DrawStripFace(const string nm, const int x, const int y, const int w, const int h,
                   const string res, const string tip)
{
   return DrawStripFaceZ(nm, x, y, w, h, res, tip, Z_STRIP_OVER);
}
//--- P-DRAW-66 (2026-09-27) — THE ONE INK BASELINE. User report: «فونت پدینگ»
//--- with a crop of the badge sitting on the row's top edge. The retired writer
//--- added a bare `y + 5` — one constant for every point size and every DPI, and
//--- right only at 192. Its measured errors at 96 DPI: the quick row's badge 5px
//--- high, the foot buttons 8px, the version chip 7px, the board header 4px low.
//--- Three owners now, and a caller names its BAND, never an ink offset:
//---   StrapInkY  — one line centred in a band
//---   StrapInkY2 — a two-line stack centred as a block (returns line 0's top)
//---   DrawStripLblAt — the raw writer, for a y that is already resolved
int StrapInkY(const int bandTop, const int bandH, const int pt)
{
   int y = bandTop + (bandH - PnlLineH(pt)) / 2;
   return (y < bandTop) ? bandTop : y;
}
int StrapInkY2(const int bandTop, const int bandH, const int ptA, const int ptB)
{
   int h = PnlLineH(ptA) + DSTRIP_INK_GAP + PnlLineH(ptB);
   int y = bandTop + (bandH - h) / 2;
   return (y < bandTop) ? bandTop : y;
}
//--- left-aligned ink for list rows (buttons centre their text; rows read left).
//--- `inkTop` IS the ink's top; a caller with a band asks DrawStripLblIn instead.
bool DrawStripLblAt(const string nm, const int x, const int inkTop, const string txt,
                    const color ink, const string tip, const int pt, const bool bold)
{
   //--- P-DRAW-124/125 — A LABEL THAT IS NEVER BORN LEAVES NO TRACE, and a label born
   //--- of ANOTHER TYPE paints nothing either. One reader answers both: the type check.
   DrawStripForeign(nm, OBJ_LABEL);
   int made = 0;
   if(ObjectFind(0, nm) < 0)
   {
      if(!ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0))
      {
         //--- P-DRAW-124: name the one silent path in the label's own birth, once a
         //--- session, with the terminal's error (P-DRAW-73's one-shot idiom).
         static bool saidLblBirth = false;
         if(!saidLblBirth)
         {
            saidLblBirth = true;
            Print("[drawstrip] label birth failed obj=", nm, " err=", GetLastError());
         }
         return false;
      }
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, Z_STRIP_OVER);
      made = 1;
   }
   bool dirty = (made > 0);   // P-DRAW-125: a birth IS a change
   //--- P-DRAW-120: the same heal for the ink. A label born under an older rung (or
   //--- behind the plate after the wide pass moved its row into the second column)
   //--- kept that rung forever, and its TEXT/COLOUR/ZORDER reads in TABCENSUS stayed
   //--- correct while the screen never painted it. Two compare-guarded writes.
   dirty |= DrawStripSetInt(nm, OBJPROP_ZORDER, Z_STRIP_OVER);
   dirty |= DrawStripSetInt(nm, OBJPROP_BACK, false);
   dirty |= DrawStripSetInt(nm, OBJPROP_XDISTANCE, x);
   dirty |= DrawStripSetInt(nm, OBJPROP_YDISTANCE, inkTop);
   dirty |= DrawStripSetInt(nm, OBJPROP_COLOR, ink);
   dirty |= DrawStripSetInt(nm, OBJPROP_FONTSIZE, PnlPt(pt));
   dirty |= DrawStripSetStr(nm, OBJPROP_FONT, BioChromeFont(bold));
   dirty |= DrawStripSetStr(nm, OBJPROP_TEXT, txt);
   dirty |= DrawStripSetStr(nm, OBJPROP_TOOLTIP, tip);
   DrawStripDiagExpect(nm, "lbl", x, inkTop, 0, 0, Z_STRIP_OVER, txt);
   return dirty;
}
//--- the everyday face: a line centred in the band it belongs to.
bool DrawStripLblIn(const string nm, const int x, const int bandTop, const int bandH,
                    const string txt, const color ink, const string tip,
                    const int pt, const bool bold)
{
   return DrawStripLblAt(nm, x, StrapInkY(bandTop, bandH, pt), txt, ink, tip, pt, bold);
}
bool DrawStripRect(const string nm, const int x, const int y, const int w, const int h,
                   const color face, const int z)
{
   DrawStripForeign(nm, OBJ_RECTANGLE_LABEL);   // P-DRAW-125: the type, not the name
   int made = 0;
   if(ObjectFind(0, nm) < 0)
   {
      if(!ObjectCreate(0, nm, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return false;
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, nm, OBJPROP_BORDER_COLOR, face);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, z);
      made = 1;
   }
   bool dirty = (made > 0);   // P-DRAW-125: a birth IS a change
   //--- P-DRAW-122 (2026-10-01) — THE LAYER IS RE-ASSERTED EVERY PAINT, NOT ONLY AT
   //--- BIRTH. P-DRAW-120 stated the law and healed the two painters the 15:18 shot
   //--- convicted (face, label); the rule is the RULE, so it now covers the rest of
   //--- the family: equal z is settled by CREATION ORDER, so an object that survives a
   //--- reattach keeps the rung it was born with, and a rect the census reads at the
   //--- right seat with the right ink paints UNDER the plate. Compare-guarded (the
   //--- shared write path), so a still frame costs two reads and writes nothing.
   dirty |= DrawStripSetInt(nm, OBJPROP_ZORDER, z);
   dirty |= DrawStripSetInt(nm, OBJPROP_BACK, false);
   dirty |= DrawStripSetInt(nm, OBJPROP_XDISTANCE, x);
   dirty |= DrawStripSetInt(nm, OBJPROP_YDISTANCE, y);
   dirty |= DrawStripSetInt(nm, OBJPROP_XSIZE, w);
   dirty |= DrawStripSetInt(nm, OBJPROP_YSIZE, h);
   dirty |= DrawStripSetInt(nm, OBJPROP_BGCOLOR, face);
   DrawStripDiagExpect(nm, "rect", x, y, w, h, z, "");
   return dirty;
}
//--- "#RRGGBB" of a colour and back moved DOWN to DrawToolbar.mqh (P-DRAW-48):
//--- the description tags the slot owner writes are the same question, so one
//--- owner answers both (an A-12 move — not one call site changed).

//--- P-DRAW-13: gear list rows — one owner for text/face/tip/state, read by
//--- layout (nothing: rows are full-width), paint and router alike.
string DrawStripGearRowText(const int r)
{
   if(r < 0 || r >= s_dsGRN) return "";
   int kind = s_dsGRKind[r], arg = s_dsGRArg[r];
   if(kind == 1) return DrawStripSwitchName(s_dsObj, arg);
   if(kind == 2) return DrawPresetName(s_dsKind, arg);
   if(kind == 3) return "Save current look";
   if(kind == 4) return DrawStripGearLevelText(arg);
   if(kind == 5)
   {
      if(arg == 0) return "All levels on";
      if(arg == 1) return "No levels";
      return "Reset layout";
   }
   if(kind == 6)
   {
      if(arg == DRAW_SLOT_MORE) return "Levels";
      return DrawStripSlotText(s_dsKind, arg, s_dsObj);
   }
   if(kind == 7) return "New " + DrawKindName(s_dsKind) + " wears this look";
   if(kind == 8) return "G" + IntegerToString(DrawStripGlyphAt(arg % 256));
   //--- P-DRAW-117: a GROUP HEADER carries its own name — the row's label IS the
   //--- group's word now, so the panel's nav has no second table to drift from.
   if(kind == DSTRIP_GRK_GROUP) return DrawStripGearGroupText(arg);
   return "";
}
string DrawStripGearRowRes(const int r)
{
   if(r < 0 || r >= s_dsGRN) return "";
   int kind = s_dsGRKind[r], arg = s_dsGRArg[r];
   if(kind == 1)
   {
      if(arg == DRAW_SLOT_COLOR) return "::Files\\Icons\\gl_droplet_m.bmp";
      return DrawStripIconRes(arg, s_dsObj);
   }
   if(kind == 2 || kind == 7) return "::Files\\Icons\\gl_template_m.bmp";
   if(kind == 3) return "::Files\\Icons\\gl_plus_m.bmp";
   if(kind == 4) return "::Files\\Icons\\bk_levels.bmp";
   if(kind == 6)
   {
      if(arg == DRAW_SLOT_MORE) return "::Files\\Icons\\bk_levels.bmp";
      if(arg == DRAW_SLOT_COLOR) return "::Files\\Icons\\gl_droplet_m.bmp";
      return DrawStripIconRes(arg, s_dsObj);
   }
   if(kind == 8) return "::Files\\Icons\\bk_glyph.bmp";
   if(kind == DSTRIP_GRK_GROUP) return DrawStripGearGroupRes(arg);   // P-DRAW-117
   return "";
}
string DrawStripGearRowTip(const int r)
{
   if(r < 0 || r >= s_dsGRN) return "";
   int kind = s_dsGRKind[r], arg = s_dsGRArg[r];
   string scope = DrawStripTipScope();
   if(kind == 1) return DrawStripSlotTip(s_dsKind, arg, s_dsObj);
   if(kind == 2)
      return "Template: " + DrawPresetName(s_dsKind, arg) +
             (DrawPresetIsBuiltin(arg) ? " (built-in)" : " (mine)") +
             " — click to apply" + scope +
             (DrawPresetIsBuiltin(arg) ? "" : " — Shift+click deletes it");
   if(kind == 3) return "Save this look as one of MY templates";
   if(kind == 4)
   {
      double v = DrawStripGearLevelAt(arg);
      if(!MathIsValidNumber(v)) return "";
      bool on = (DrawStripLevelFind(s_dsObj, v) >= 0);
      return DrawStripLevelName(v) + (on ? " is on — switch removes, label notes, swatch colors" : " — click to add") +
             " (the held drawing; stays open for the next one)";
   }
   if(kind == 5)
   {
      if(arg == 0) return "Every common level on (the held drawing)";
      if(arg == 1) return "Empty the level set (the held drawing)";
      return "Show every slot of this tool again";
   }
   if(kind == 6) return "Show this slot in the quick row — click to hide / show";
   if(kind == 7) return "Learn the look on the chart as this tool's default (next drawing wears it)";
   if(kind == 8)
      return "Arrow mark: glyph " + IntegerToString(DrawStripGlyphAt(arg % 256)) + " — click to apply" + scope;
   if(kind == DSTRIP_GRK_GROUP) return DrawStripGearGroupTip(arg);   // P-DRAW-117
   return "";
}
bool DrawStripGearRowIsCur(const int r)
{
   if(r < 0 || r >= s_dsGRN) return false;
   int kind = s_dsGRKind[r], arg = s_dsGRArg[r];
   if(kind == 1) return DrawStripSlotOn(arg, s_dsObj);
   if(kind == 2) return (arg == s_dsTpl[s_dsKind]);
   if(kind == 4)
   {
      double v = DrawStripGearLevelAt(arg);
      return (MathIsValidNumber(v) && DrawStripLevelFind(s_dsObj, v) >= 0);
   }
   if(kind == 6)
   {
      if(arg == DRAW_SLOT_MORE) return DrawStripVis(s_dsKind, DSTRIP_SLOT_LEVELS);
      return DrawStripVis(s_dsKind, arg);
   }
   if(kind == 8)
      return ((int)DrawSlotRead(s_dsObj, DRAW_SLOT_GLYPH) == DrawStripGlyphAt(arg % 256));
   //--- P-DRAW-117: a group header is "current" exactly while ITS settings are the
   //--- ones on screen — the open group, and not folded away.
   if(kind == DSTRIP_GRK_GROUP) return (arg == s_dsGear && !s_dsGearCollapsed);
   return false;
}
//--- P-DRAW-117 (2026-10-01) — THE VALUE THE GROUP HOLDS, ON ITS OWN ROW.
//--- A folded panel still answers the first question a settings card is asked
//--- («این شکل الان چی پوشیده؟»): Color states the border's hex and the interior's
//--- tone, Stroke the width and the line style, Levels how many levels the held
//--- drawing shows, Look the template in force, Row how many cells the quick row
//--- carries — and the Mark group its face. ONE owner: read by the row's paint and
//--- by the row's tooltip, never re-derived at either site.
//--- Bounded: a handful of slot reads and one text format per group row per paint
//--- (five rows), and nothing here runs in the mouse or tick stream.
string DrawStripGearGroupDigest(const int gid)
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return "";
   if(gid == DSTRIP_GEAR_PAINT)
   {
      string hex = DrawStripColorHex((color)(int)DrawSlotRead(s_dsObj, DRAW_SLOT_COLOR));
      if(!DrawSlotAvailable(s_dsKind, DRAW_SLOT_FILL)) return hex;
      if(DrawSlotRead(s_dsObj, DRAW_SLOT_FILL) < 0.5) return hex;
      return hex + " · " + IntegerToString((int)DrawSlotAlphaGet(s_dsObj, DRAW_SLOT_FILLCLR)) + "%";
   }
   if(gid == DSTRIP_GEAR_STYLE)
   {
      int w = (int)DrawSlotRead(s_dsObj, DRAW_SLOT_WIDTH);
      string st = DrawStripPickText(s_dsKind, DRAW_SLOT_STYLE, (int)DrawSlotRead(s_dsObj, DRAW_SLOT_STYLE));
      if(w < 1 || w > 5) return st;
      if(st == "") return IntegerToString(w) + "px";
      return IntegerToString(w) + "px · " + st;
   }
   if(gid == DSTRIP_GEAR_LEVELS)
   {
      int n = DrawStripGearLevelCount();
      return (n == 1) ? "1 level" : (IntegerToString(n) + " levels");
   }
   if(gid == DSTRIP_GEAR_MARK)
   {
      if(s_dsKind == DK_TEXT)
         return IntegerToString((int)DrawSlotRead(s_dsObj, DRAW_SLOT_FONT)) + "pt";
      return "glyph " + IntegerToString((int)DrawSlotRead(s_dsObj, DRAW_SLOT_GLYPH));
   }
   if(gid == DSTRIP_GEAR_TPL)
   {
      if(s_dsKind <= DK_NONE || s_dsKind >= DK_COUNT) return "";
      string nm = DrawPresetName(s_dsKind, s_dsTpl[s_dsKind]);
      return (nm == "") ? "none" : nm;
   }
   //--- the Row group: how many cells the quick row really shows, counted by the
   //--- SAME conditions its own list is built with (available slots, minus the more
   //--- seat, plus the levels cell on the kinds that have levels).
   if(gid != DSTRIP_GEAR_STRIP) return "";   // P-DRAW-117: the fallback is EMPTY —
                                              // an unknown group states nothing
   DrawStripVisInit();
   int on = 0;
   for(int s = 0; s < DRAW_SLOT_N; s++)
   {
      if(s == DRAW_SLOT_MORE) continue;
      if(!DrawSlotAvailable(s_dsKind, s)) continue;
      if(DrawStripVis(s_dsKind, s)) on++;
   }
   if(DrawKindHasLevels(s_dsKind) && DrawStripVis(s_dsKind, DSTRIP_SLOT_LEVELS)) on++;
   return IntegerToString(on) + " cells";
}

//--- action X, ONE owner (Layout's quickW and Paint read the same answer).
//--- P-DRAW-66: a face of the layout's own seat array — the command group's x is
//--- computed ONCE (in DrawStripLayout) and every reader asks the same table.
int DrawStripActX(const int a)
{
   if(a < 0 || a >= DSTRIP_ACT_N) return DSTRIP_PAD;
   return s_dsActX[a];
}
string DrawStripSepName(const int g) { return "PnlDrawS_SEP" + IntegerToString(g); }

//--- gear edit row: created with its seed, never re-seeded after (a repaint
//--- rewriting the TEXT would fight the user's typing mid-word).
//--- P-DRAW-32: `y` is the PANEL's own row top — the plate's origin is added
//--- exactly once, HERE, so the two surfaces' coordinate spaces stay apart.
//--- P-DRAW-100: ...UNLESS THE CALLER SAYS THE FIELD MAY FOLLOW ITS VALUE. That
//--- sentence above was the whole of the rule, and for the two colour fields it
//--- made the field a LIE: `OBJPROP_TEXT` was written once, inside the create, so
//--- the Paint tab's `COLOR` box showed the hex the drawing wore the first time the
//--- tab was opened and nothing ever changed it. Press `Reset` in the foot
//--- (`DrawPresetApply`, DrawStrip_Tap) or pick a colour on the board and the
//--- drawing changed while the field kept the old hex — the one field whose whole
//--- job is to state the current value, stating a value the drawing had left. The
//--- board's own hex field already solved this and its law is copied here verbatim
//--- (`DrawStripPopHex`, this file): a guarded write that follows the value, and an
//--- EMPTY seed never writes, so the field the user is typing in is the caller's
//--- word to keep. `reseed` is that word: the two hex seats pass the value while
//--- `s_dsHexFocus` is false, the three typed seats pass false and are untouched.
bool DrawStripEdit(const int e, const int x, const int y, const int w,
                   const string seed, const string tip, const bool reseed)
{
   string nm = DrawStripEditName(e);
   bool dirty = false;
   if(ObjectFind(0, nm) < 0)
   {
      if(!ObjectCreate(0, nm, OBJ_EDIT, 0, 0, 0)) return false;
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, PnlPt(8));
      //--- P-DRAW-67: the cards' field font. Without this the gear's hex fields wore
      //--- MT4's own default face while the cards and the strip's own board wore
      //--- Consolas — the "same field, two fonts" half of the report.
      ObjectSetString(0, nm, OBJPROP_FONT, BIO_FONT_MONO);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, DSTRIP_CLR_LABEL);
       ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, DSTRIP_CLR_FIELD);
       ObjectSetInteger(0, nm, OBJPROP_BORDER_COLOR, DSTRIP_CLR_FIELD_BD);
       ObjectSetInteger(0, nm, OBJPROP_BORDER_TYPE, BORDER_FLAT);
       ObjectSetInteger(0, nm, OBJPROP_ALIGN, ALIGN_LEFT);
       ObjectSetInteger(0, nm, OBJPROP_READONLY, false);

      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, Z_STRIP_ICON);
      ObjectSetString(0, nm, OBJPROP_TEXT, seed);
      dirty = true;
   }
   else if(reseed && seed != "" && ObjectGetString(0, nm, OBJPROP_TEXT) != seed)
      dirty |= DrawStripSetStr(nm, OBJPROP_TEXT, seed);
   //--- P-DRAW-122: the layer, every paint — a field that survives a reattach with an
   //--- older rung paints under the plate, and the ROW'S OWN WORD is what goes missing.
   dirty |= DrawStripSetInt(nm, OBJPROP_ZORDER, Z_STRIP_ICON);
   dirty |= DrawStripSetInt(nm, OBJPROP_BACK, false);
   dirty |= DrawStripSetInt(nm, OBJPROP_XDISTANCE, x);
   dirty |= DrawStripSetInt(nm, OBJPROP_YDISTANCE, s_dsGEY + y + (DSTRIP_GEAR_ROW_H - DSTRIP_GEAR_EDIT_H) / 2);
   dirty |= DrawStripSetInt(nm, OBJPROP_XSIZE, w);
   dirty |= DrawStripSetInt(nm, OBJPROP_YSIZE, DSTRIP_GEAR_EDIT_H);
   dirty |= DrawStripSetStr(nm, OBJPROP_TOOLTIP, tip);
   return dirty;
}
//--- TV parity board: the HEX field. It is NOT a gear edit (`DrawStripEdit` adds
//--- the settings panel's own origin), so it has its own owner and its own name.
//--- P-DRAW-48: the seed is the LIVE colour now — the field used to be seeded once
//--- and a grid pick left the old hex on screen («hex ناقص پیاده سازی شده»);
//--- `s_dsHexFocus` is the one guard: while the user is typing, nothing writes.
bool DrawStripPopHex(const int x, const int y, const int w, const string seed)
{
   string nm = DrawStripPHexEdName();
   bool dirty = false;
   if(ObjectFind(0, nm) < 0)
   {
      if(!ObjectCreate(0, nm, OBJ_EDIT, 0, 0, 0)) return false;
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, PnlPt(8));
      ObjectSetString(0, nm, OBJPROP_FONT, BIO_FONT_MONO);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, DSTRIP_CLR_LABEL);
      ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, DSTRIP_CLR_FIELD);
      ObjectSetInteger(0, nm, OBJPROP_BORDER_COLOR, DSTRIP_CLR_FIELD_BD);
      ObjectSetInteger(0, nm, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, nm, OBJPROP_ALIGN, ALIGN_LEFT);
      ObjectSetInteger(0, nm, OBJPROP_READONLY, false);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, Z_STRIP_ICON);
      ObjectSetString(0, nm, OBJPROP_TEXT,
                      DrawStripColorHex((color)(int)DrawSlotRead(s_dsObj, DRAW_SLOT_COLOR)));
      dirty = true;
   }
   //--- the live seed: a guarded write, so a repaint that changed nothing writes
   //--- nothing — and the field follows a colour picked on the grid or typed
   //--- elsewhere. An empty seed (the field holds the focus) never writes.
   if(seed != "" && ObjectGetString(0, nm, OBJPROP_TEXT) != seed)
      dirty |= DrawStripSetStr(nm, OBJPROP_TEXT, seed);
   //--- P-DRAW-122: the layer, every paint (same heal as the panel's fields and rects:
   //--- a bare HEX box on the board is this field painting under the plate).
   dirty |= DrawStripSetInt(nm, OBJPROP_ZORDER, Z_STRIP_ICON);
   dirty |= DrawStripSetInt(nm, OBJPROP_BACK, false);
   dirty |= DrawStripSetInt(nm, OBJPROP_XDISTANCE, x);
   dirty |= DrawStripSetInt(nm, OBJPROP_YDISTANCE, y);
   dirty |= DrawStripSetInt(nm, OBJPROP_XSIZE, w);
   dirty |= DrawStripSetInt(nm, OBJPROP_YSIZE, DSTRIP_POP_EDIT_H);
   dirty |= DrawStripSetStr(nm, OBJPROP_TOOLTIP,
                            "Type #RRGGBB, Enter applies it" + DrawStripTipScope());
   return dirty;
}
//--- P-DRAW-90 (2026-09-30) — THE FOOT'S THREE COMMANDS AND ITS OWN GRID.
//--- The design draws `Reset | All · Copy`; the code shipped `All · Copy` and
//--- put the reset ring on `All`. Three owners now, one per question: the LABEL
//--- and its tooltip, the GLYPH (only `Reset` wears one — the mock's own rule;
//--- `""` makes DrawStripFace DELETES the face, which is the orphan sweep for the
//--- ring the old `All` wore), and the SEAT (`DrawStripFootX`).
//--- `DrawStripFootX` is read by the paint (DrawStripGearPaint) AND the hit test
//--- (DrawStripGearHit): the same arithmetic in two places is a second grid, and
//--- the old foot proved it — it stood at `px + f*(bw+gap)` twice, once in each.
string DrawStripFootText(const int f)
{
   if(f == 0) return "Reset";
   return (f == 1) ? "All" : "Copy";
}
string DrawStripFootTip(const int f)
{
   if(f == 0) return "This " + DrawKindName(s_dsKind) + " back to its factory look (undoable)";
   if(f == 1) return "This look on EVERY " + DrawKindName(s_dsKind) + " (MT4's dialog is one at a time)";
   return "Copy this drawing beside itself (selects the copy)";
}
string DrawStripFootRes(const int f)
{
   return (f == 0) ? "::Files\\Icons\\gl_reset_m.bmp" : "";
}
//--- P-DRAW-80: the cards' OWN width formula, `max(72, 32 + advance + 8)`.
int DrawStripFootBw(const int f)
{
   return MathMax(DSTRIP_GEAR_FOOT_BW, 32 + PnlTextW(DrawStripFootText(f), 8) + 8);
}
//--- the seat: `f == 0` at the content's left edge, the rest a pair flush to its
//--- right. `cw` is the foot's own content width — DrawStripGearColW(), the same
//--- answer on a 312 tab and on a 624 one (280 / 592).
int DrawStripFootX(const int f, const int px, const int cw)
{
   if(f <= 0) return px;
   int total = 0;
   for(int i = 1; i < DSTRIP_GEAR_FOOT_N; i++)
      total += DrawStripFootBw(i) + ((i > 1) ? DSTRIP_GEAR_FOOT_GAP : 0);
   int x = px + cw - total;
   for(int i = 1; i < f; i++) x += DrawStripFootBw(i) + DSTRIP_GEAR_FOOT_GAP;
   return x;
}
//--- P-DRAW-107 (2026-10-01) — THE SEAT IS THE CENTRE OF THE BUTTON.
//--- P-DRAW-80 copied the cards' left-aligned pair (`glyph at bx+12`, `label at
//--- bx+32`, BiotakPanels 6486-6507) onto this foot. A card's footer button is
//--- ~100px wide and left-aligned ink reads as a button there; this foot's plate is
//--- `DSTRIP_GEAR_FOOT_BW` 72 and the same seat parks the word against its LEFT
//--- edge. MEASURED with the panel's own metrics (`mt4.text_w`, `PnlTextW`): `All`
//--- is 14px and began at `fx+16` inside a plate whose own fill runs `fx+2 .. fx+70`
//--- — 14px of plate to its left, 40px to its right; `Copy` (27px) 14/27 and
//--- `Reset` (29px, after its ring) 12/18. The button's ink is ONE group,
//--- `[ring 15 + ADV][word]`, so the GROUP is what is centred:
//--- `x0 = fx + (bw - adv - tw) / 2`, and the ring sits one ADV inside it. `Reset`
//--- therefore moves 1px, `Copy` 6 and `All` 13, and each word's own gaps come out
//--- 27/27 (`Reset` 9/10 around its ring+word pair). The width, the advance and the
//--- advance's own number are each ONE owner.
int DrawStripFootLabelX(const int f, const int fx)
{
   int adv = (DrawStripFootRes(f) == "") ? 0 : DSTRIP_GEAR_FOOT_GLYPH_ADV;
   return fx + (DrawStripFootBw(f) - adv - PnlTextW(DrawStripFootText(f), 8)) / 2 + adv;
}
//--- the ring's own seat: ONE advance left of the word it belongs to, so the pair
//--- cannot drift apart on a measured plate (P-DRAW-90: `Reset` is the one action
//--- the design gives a glyph, and an empty `DrawStripFootRes` makes DrawStripFaceZ
//--- DELETE the seat — the sweep for the ring the old two-button foot wore on `All`).
int DrawStripFootGlyphX(const int f, const int fx)
{
   return DrawStripFootLabelX(f, fx) - DSTRIP_GEAR_FOOT_GLYPH_ADV;
}
//--- the gear panel's own paint: tabs, grids, rows, edits, foot.
string DrawStripGearHeadTitle()
{
   return DrawKindName(s_dsKind) + " Settings";
}
//--- P-DRAW-117 (2026-10-01) — THE HEAD STATES THE DRAWING, NOT ITS PAPERWORK.
//--- The second line carried `SERVING n DRAWINGS` — a count the strip's own badge
//--- already carries — while the one thing a settings card is opened to see stood
//--- nowhere on it: what this drawing wears RIGHT NOW. The line is the LIVE look
//--- now — the border's hex, the width, the line style, and the interior's tone when
//--- the drawing has one — read through the same slot owners every other surface
//--- reads, and re-read on every paint (so a board pick, a template, or the foot's
//--- own Reset moves it in the same frame).
string DrawStripGearHeadSub()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return "";
   string line = DrawStripColorHex((color)(int)DrawSlotRead(s_dsObj, DRAW_SLOT_COLOR));
   int w = (int)DrawSlotRead(s_dsObj, DRAW_SLOT_WIDTH);
   if(w >= 1 && w <= 5) line += " · " + IntegerToString(w) + "px";
   string st = DrawStripPickText(s_dsKind, DRAW_SLOT_STYLE, (int)DrawSlotRead(s_dsObj, DRAW_SLOT_STYLE));
   if(st != "") line += " · " + st;
   if(DrawSlotAvailable(s_dsKind, DRAW_SLOT_FILL) && DrawSlotRead(s_dsObj, DRAW_SLOT_FILL) >= 0.5)
      line += " · " + IntegerToString((int)DrawSlotAlphaGet(s_dsObj, DRAW_SLOT_FILLCLR)) + "%";
   return line;
}
string DrawStripGearMarkRes()
{
   if(s_dsKind == DK_RECT || s_dsKind == DK_TRIANGLE || s_dsKind == DK_ELLIPSE)
      return "::Files\\Icons\\gl_box_i_gold.bmp";
   if(s_dsKind == DK_FIBO || s_dsKind == DK_FIBOFAN || s_dsKind == DK_FIBOCHAN ||
      s_dsKind == DK_EXPANSION || s_dsKind == DK_GANN)
      return "::Files\\Icons\\gl_sigma_i_gold.bmp";
   if(s_dsKind == DK_ARROW) return "::Files\\Icons\\gl_target_i_gold.bmp";
   if(s_dsKind == DK_TEXT) return "::Files\\Icons\\gl_type_i_gold.bmp";
   return "::Files\\Icons\\gl_line_i_gold.bmp";
}
bool DrawStripGearHeadPaint()
{
   bool dirty = false;
   int gx = DrawStripGearX();
   int hy = s_dsGEY + s_dsGearHeadY;
   // P-DRAW-31: the header IS a handle, and it says so (the whole top row of the
   // plate carries it too — see DrawStripGripWhich).
   string tip = DrawKindName(s_dsKind) + " settings — drag this bar to move the panel";
    // P-DRAW-36 (2026-09-25): the head spans the PLATE's own width, not the content
    // width — the old `s_dsGearW` left a bare 32px strip of plate on the right while
    // the left sat at 16px, so the header read as narrower than the card it belongs
    // to (the cards' own header spans the whole card).
     //--- P-DRAW-73: through a LOCAL. This painter used to write `s_dsGearW =
     //--- s_dsGearW0`, so a layout variable carried the plate's width from the first
     //--- paint on — two meanings in one name, and the one reader (`DrawStripGearCW`,
     //--- no callers, retired below) answered 312 where the layout means 280.
     int pw = s_dsGearW0;
     bool gearWide = (pw > DSTRIP_GEAR_W);
     string tbRes  = gearWide ? "::Files\\Icons\\pnl_topbarW_gold.bmp" : "::Files\\Icons\\pnl_topbar_gold.bmp";
     string hrRes  = gearWide ? "::Files\\Icons\\pnl_hairW_gold.bmp"   : "::Files\\Icons\\pnl_hair_gold.bmp";
     //--- P-DRAW-74: a BAKED piece is asked for at its OWN width. Both bakes are
     //--- 312/624 (measured on the files) and both were asked for at the plate's
     //--- 344/656, so MT4 — which crops a label and never scales it — drew each one
     //--- 32px SHORT: the card's top edge and the seam closing the head stopped
     //--- before the plate's right edge, beside a body seam that runs full width.
      int bw = pw;   // P-DRAW-75: the plate IS the card, so the bake's 312/624 is the plate's width
      //--- P-DRAW-80: the head rides the CARDS' z ladder (BiotakPanels 6727/6729),
      //--- not the strip's. `Z_STRIP_ICON` is 1441, BELOW the whole panel range
      //--- (1480+), so the card body painted over its own top bar and hair.
      dirty |= DrawStripFaceZ(DrawStripGearHeadName("TB"), gx, hy, bw, DSTRIP_GEAR_TB_H,
                              tbRes, tip, Z_PANEL_TOPBAR);
      //--- P-DRAW-73: the hair CLOSES the head, so it ends ON the head's bottom edge.
      //--- It stood at +53 with height 5 inside a 56px head — 2px into the tab row,
      //--- while P-DRAW-69's seam rides that same edge at exactly HEAD_H.
      dirty |= DrawStripFaceZ(DrawStripGearHeadName("HR"), gx,
                              hy + DSTRIP_GEAR_HEAD_H - DSTRIP_GEAR_HR_H, bw, DSTRIP_GEAR_HR_H,
                              hrRes, tip, Z_PANEL_HAIR);
     //--- P-DRAW-83: THE SECOND WRITE IS DELETED. This pair was one intent pasted
     //--- twice — the same object, the same rect, the same tooltip — and only the
     //--- rung differed: `Z_PANEL_HAIR` 1495 first, `Z_STRIP_ICON` 1441 second. The
     //--- second one WON (a later write is the value the terminal holds), so the hair
     //--- the P-DRAW-73 note above places on the head's bottom edge was re-sat on the
     //--- strip's icon rung, under the top bar it closes and under the section rules.
     //--- One owner, one write: the rung above is the one the note describes.
   //--- P-DRAW-80: THE HEADER, ON THE CARDS' OWN SEATS (BiotakPanels 6734-6742).
   //--- mark canvas 44 at `+16-7, +13-7`; glyph 15 at `+16+7, +13+7`; text
   //--- column at `+16+30+10`. This panel drew the mark in a 30px box at +16
   //--- (7px right and 7px low of the cards' canvas) and the glyph by hand at
   //--- +23/+20 — so the disc floated off its own glyph and the whole head sat
   //--- 7px off the card it belongs to. LITERALS, not PNL_*: BiotakPanels is
   //--- included AFTER this file.
   dirty |= DrawStripFace(DrawStripGearHeadName("MK"), gx + 9, hy + 6, 44, 44,
                           "::Files\\Icons\\pnl_mark_gold.bmp", tip);
   dirty |= DrawStripFace(DrawStripGearHeadName("MG"), gx + 23, hy + 20, 15, 15,
                           DrawStripGearMarkRes(), tip);
   int htx = gx + 56;   // PNL_PAD_X + PNL_MARK_VIS + 10
   // P-DRAW-36: the version chip and the close button sit at the PLATE's right
   // inset (s_dsGearW0 - PAD), so they read as flush with the content's own
   // right edge instead of 32px short of it.
    //--- P-DRAW-71: the cards' own `.ver` — 16px high at +20, as wide as its own
    //--- text (10 + the advance at pt 6), a 6px gap before the X (the fixed 46x22
    //--- gold chip stood 30px wider than any number it holds).
    //--- P-DRAW-73: it carries a VERSION. It wore `(int)s_dsKind`, so a rectangle
    //--- read "11" — a number the user cannot act on or quote (J-02).
    //--- P-BUILD-08: the OLD tag here was a hand-typed word ("T2") that did not
    //--- change when the code did, so two different ex4s showed the same chip. The
    //--- chip now shows the SHORT form of the SAME source hash the log prints as
    //--- [BUILD] src= (Biotak/BuildHash.mqh) — screen and log, one voice, and it
    //--- moves the moment any compiled byte moves. 8 chars, not 16: the chip is
    //--- 16px high and stands in a 312px head, and the log carries the full hash.
    string ver = TH3_SRC_SHORT;
   int vw = 10 + PnlTextW(ver, 6);
   //--- P-DRAW-80: the right column, on the cards' own chain (BiotakPanels
   //--- 6749-6755/6857): ver left = cardW-16-26-6-vw, and the close sits
   //--- 6px right of it. This panel put the chip at `-16-26-6-vw` of the WIDTH
   //--- but measured from `s_dsGearW0` while the head spans the same value —
   //--- consistent, so the 6px gap is kept; what moved is the chip's own y.
   int verX = gx + s_dsGearW0 - 16 - 26 - 6 - vw;
   if(verX < htx + 10) verX = htx + 10;                        // a narrow panel keeps the old seat
   //--- P-DRAW-80: the two lines are NOT centred as a block. The cards place
   //--- title at `+12` and subtitle at `+35` (BiotakPanels 6762/6834) — the
   //--- vertical centring this panel inherited from the strip left both
   //--- floating and the pair read lower than every card's. Same two numbers.
   dirty |= DrawStripLblAt(DrawStripGearHeadName("TT"), htx, hy + 12,
                           PnlFit(DrawStripGearHeadTitle(), 9, verX - htx - 10),
                           DSTRIP_CLR_VALUE, tip, 9, true);
   dirty |= DrawStripLblAt(DrawStripGearHeadName("ST"), htx, hy + 35,
                           PnlFit(DrawStripGearHeadSub(), 6, verX - htx - 10),
                           DSTRIP_CLR_TITLE, tip, 6, true);   // = BIO_CLR_MUTED
   //--- P-DRAW-71: ONE object, the cards' own `.ver` chip — a 16px face in the
   //--- accent soft/border pair with the number centred in it (was a 50x26 BMP plus
   //--- a label, and the pair could drift apart).
   dirty |= DrawStripBtn(DrawStripGearHeadName("VB"), verX, hy + 20, vw, 16,
                         DSTRIP_CLR_VER_BG, DSTRIP_CLR_ACCENT, DSTRIP_CLR_VER_BD, ver, tip);
   dirty |= DrawStripSetInt(DrawStripGearHeadName("VB"), OBJPROP_FONTSIZE, PnlPt(6));
   if(ObjectFind(0, DrawStripGearHeadName("VT")) >= 0)      // the retired label
   { ObjectDelete(0, DrawStripGearHeadName("VT")); dirty = true; }
   int closeX = gx + s_dsGearW0 - DSTRIP_GEAR_PAD - 26;
   dirty |= DrawStripBtn(DrawStripGearCloseName(), closeX, hy + 17, 26, 26,
                         DSTRIP_CLR_FOOT, DSTRIP_CLR_FOOT, DSTRIP_CLR_LINE, "", "Close settings");
   dirty |= DrawStripFace(DrawStripGearCloseSkinName(), closeX, hy + 17, 26, 26,
                          "::Files\\Icons\\pnl_xbtn.bmp", "Close settings");
   dirty |= DrawStripFace(DrawStripGearCloseIconName(), closeX, hy + 17, 26, 26,
                          "::Files\\Icons\\gl_x_gold.bmp", "Close settings");
   return dirty;
}
//--- P-DRAW-71 — A BAND'S OWN MEMBER COUNT, the cards' `.cnt`. One owner walks
//--- the tab's blocks: a ROW, or a chip BLOCK (one setting, whatever its options),
//--- whose y sits inside this band's range and in the band's own column counts
//--- once. The wide pass translates a whole block into its column, so the column
//--- filter is what keeps the count honest on a two-column panel.
//--- P-DRAW-121 (2026-10-01) — AND A GROUP HEADER IS NOT A MEMBER. The accordion's
//--- own nav rides the SAME row array (`s_dsGR*`, P-DRAW-117) in the SAME column, so
//--- on a wide tab the headers BELOW the open group pack into the last band's range
//--- and this loop counted them as settings: reported from the terminal as the Stroke
//--- tab's LAYER pill reading 4 (`Behind candles` + `Look` + `Row` for a band that
//--- owns TWO rows, Lock and Behind candles), and the same rule gave the Colour tab's
//--- FILL band 5 for its two members. Reproduced offline by
//--- `python tools/debug-doctor.py --symptom count` (S3), whose delta IS the defect:
//--- the pill counted NAV. `s_dsGRKind` is the row's own kind and the group row is
//--- `DSTRIP_GRK_GROUP`, so the row loop skips it and nothing else moves — the grid
//--- loop below was never affected (a header writes no `s_dsGG` cell).
int DrawStripGearSectionCount(const int i)
{
   if(i < 0 || i >= s_dsGearSecN) return 0;
   int col = s_dsGearSecCol[i], y0 = s_dsGearSecY[i], y1 = 0x7FFFFFFF;
   for(int j = i + 1; j < s_dsGearSecN; j++)
      if(s_dsGearSecCol[j] == col && s_dsGearSecY[j] > y0 && s_dsGearSecY[j] < y1)
         y1 = s_dsGearSecY[j];
   int n = 0;
   for(int r = 0; r < s_dsGRN; r++)
      if(s_dsGRKind[r] != DSTRIP_GRK_GROUP &&
         s_dsGRCol[r] == col && s_dsGRY[r] >= y0 && s_dsGRY[r] < y1) n++;
   for(int g = 0; g < s_dsGGN; g++)
   {
      if(s_dsGGY[g] < y0 || s_dsGGY[g] >= y1) continue;
      if(((s_dsGGX[g] >= DSTRIP_GEAR_COL) ? 1 : 0) != col) continue;
      bool dup = false;
      for(int h = 0; h < g; h++)
         if(s_dsGGY[h] == s_dsGGY[g] &&
            (((s_dsGGX[h] >= DSTRIP_GEAR_COL) ? 1 : 0) == col)) { dup = true; break; }
      if(!dup) n++;
   }
   return n;
}
bool DrawStripGearSectionsPaint(const int x, const int w)
{
   bool dirty = false;
   for(int i = 0; i < DSTRIP_GEAR_SECTION_MAX; i++)
   {
      string sn = DrawStripGearSectionName(i), sl = DrawStripGearSectionLineName(i);
      if(i >= s_dsGearSecN)
      {
         //--- P-DRAW-84 (2026-09-29) — A RETIRED BAND TAKES ITS WHOLE FAMILY WITH IT.
         //--- This branch deleted two names and only ONE of them is ever painted:
         //--- `sn` is a frame no painter creates any more (the band is the dot `snD`,
         //--- the label `snT`, the rule `sl` and — when it owns its row — the count
         //--- pill `snC` and its number `snN`). So a tab switch that SHRINKS the band
         //--- list (Style's four bands → Look's one) left the previous tab's captions,
         //--- dots and pills painted on the new tab's plate — the reported «جابجا
         //--- بین تب‌ها می‌شم این‌طوری می‌شه»: LINE STYLE / SHAPE / LAYER floating over
         //--- the template rows, two tabs in one card. Deleting a name that cannot
         //--- exist is not a delete; the family is five names and the rule makes six.
         //--- Bounded: 5 ObjectFind + 1 per retired index, per paint.
         string gone = sn;
         for(int gi = 0; gi < 5; gi++)
         {
            if(gi == 1) gone = sn + "D";
            else if(gi == 2) gone = sn + "T";
            else if(gi == 3) gone = sn + "C";
            else if(gi == 4) gone = sn + "N";
            if(ObjectFind(0, gone) >= 0) { ObjectDelete(0, gone); dirty = true; }
         }
         if(ObjectFind(0, sl) >= 0) { ObjectDelete(0, sl); dirty = true; }
         continue;
      }
      int y = s_dsGEY + s_dsGearSecY[i];
      // P-DRAW-30: the band belongs to its block's column (the hair stops at that
      // column's own right edge, never across the gutter).
      int x0 = x + s_dsGearSecCol[i] * DSTRIP_GEAR_COL;
      //--- P-DRAW-80: `x` is the CONTENT box (card + 16), the cards' captions
      //--- measure from the CARD edge — so every seat below is `+16 - 16` from
      //--- here, i.e. exactly the card's own arithmetic restated on this origin.
      //--- The card's own numbers: dot `+16-4` at `+18-4`, label `+16+14` at
      //--- `+14`, rule at `+21` 1px, count chip `cardW-58` at `+11` 24x20, the
      //--- number centred in it, rule's right end `cardW-68`.
      const int SEC_DX = DSTRIP_GEAR_PAD;   // 16 = PNL_PAD_X
      string txt = s_dsGearSecText[i];
      //--- P-DRAW-66: a caption that shares its row with a control is a ROW LABEL,
      //--- not a section band — pt 9 in the label ink, which is exactly the cards'
      //--- own row label (PNL_PT_LBL 9 / PNL_CLR_LABEL). A caption that owns its band
      //--- keeps the 7pt muted band treatment.
      bool rowLbl = (s_dsGearSecCX[i] >= 0);
      //--- P-DRAW-75 (2026-09-28): THE DOT IS THE BAND'S MARK, SO A ROW LABEL WEARS
      //--- NONE — the cards put `pnl_secdot` on `PNL_K_SEC` alone (BiotakPanels
      //--- 6053) and their row labels are bare ink ("MID ZONES", "SHOW LINES"). Here
      //--- every shared-row caption wore one, so COLOR and FILL each carried a GOLD
      //--- DOT: a second accent meaning nothing, which C-03 bans by name, on a plate
      //--- whose only accent is the active tab and the value itself.
      string dot = sn + "D";
      if(rowLbl) { if(ObjectFind(0, dot) >= 0) { ObjectDelete(0, dot); dirty = true; } }
      //--- P-DRAW-80: the cards' OWN section dot — canvas 14 at `+16-4, +18-4`
      //--- (BiotakPanels 6053-6055), on their z rung.
      else
         dirty |= DrawStripFaceZ(dot, x0 + SEC_DX - 4, y + 14, 14, 14,
                                 "::Files\\Icons\\pnl_secdot_gold.bmp", txt, Z_PANEL_CHIP);
      //--- P-DRAW-73 (2026-09-28): ONE point size for the ink and for the measure.
      //--- The rule below started at `PnlTextW(txt, 7)` while a row label draws at 9,
      //--- so every caption sharing a row had its hair start ~8px early and run
      //--- under the last letters of its own word.
      int lpt = (rowLbl ? DSTRIP_GEAR_LBL_PT : 7);
      //--- P-DRAW-80: the label sits on the card's seat — `+16+14` from the CARD,
      //--- `+14` down, muted at pt 7 for a band (BiotakPanels 6007-6008).
      dirty |= DrawStripLblIn(sn + "T", x0 + DSTRIP_GEAR_CAP_X, y, DSTRIP_GEAR_ROW_H, txt,
                              rowLbl ? DSTRIP_CLR_LABEL : DSTRIP_CLR_TITLE, txt,
                              lpt, true);
      //--- P-DRAW-66: a caption that SHARES its row with a control draws its rule
      //--- only up to that control (`s_dsGearSecCX`), never through it.
      int lx = x0 + DSTRIP_GEAR_CAP_X + PnlTextW(txt, lpt) + DSTRIP_ROW_GAP;
      //--- P-DRAW-71: a BAND (one that owns its row) also carries the cards' own
      //--- `.cnt` pill, and its rule stops 36px short of the column's right edge for
      //--- it (the pill is 24 wide + 12 of air). A caption that SHARES its row with a
      //--- control is a row label — short rule, no pill.
      int cnt = rowLbl ? 0 : DrawStripGearSectionCount(i);
      //--- P-DRAW-80: the rule's right end is the card's own formula — `cardW-16-24-12-16`
      //--- (BiotakPanels 6027) — which is 68px in from the card's right edge.
      int rEnd = (cnt > 0) ? x0 + w - 16 - 16 : x0 + w;
      int lw = (s_dsGearSecCX[i] >= 0) ? MathMin(x0 + s_dsGearSecCX[i], x0 + w) - lx
                                       : rEnd - lx;
      //--- P-DRAW-75: A RULE WITH NO ROOM IS NOT A RULE. With the seat measured, a
      //--- shared-row caption's hair measures zero or less — the label already stands
      //--- B-02's 10 from its own control — and what it used to draw there was the
      //--- 26px stub LEVEL 90 no. 4 names. A band keeps its hair; a hair with no room
      //--- takes its object with it (no. 12).
      if(lw < DSTRIP_ROW_GAP)
      {
         if(ObjectFind(0, sl) >= 0) { ObjectDelete(0, sl); dirty = true; }
      }
      else
         dirty |= DrawStripRect(sl, lx, y + 21, lw, 1, DSTRIP_CLR_LINE, Z_PANEL_BASE);
      string cchip = sn + "C", clbl = sn + "N";
      if(cnt > 0)
      {
         string cs = IntegerToString(cnt);
         //--- P-DRAW-80: the card's own `.cnt` — canvas 24x20 at `cardW-58`,
         //--- `+11` (BiotakPanels 6032-6033), and the number centred in the
         //--- CANVAS's own centre at `+16` (6039-6041). This panel drew the bake
         //--- 24x16 at a centred y and the number off that 16px box, so the pill
         //--- lost its bottom edge to MT4's crop and the digit drifted.
         dirty |= DrawStripFaceZ(cchip, x0 + w - DSTRIP_SEC_CNT_W - 2, y + 11,
                                 DSTRIP_SEC_CNT_W + 4, 20,
                                 "::Files\\Icons\\pnl_cntchip.bmp", txt, Z_PANEL_CHIP);
         dirty |= DrawStripLblAt(clbl, x0 + w - DSTRIP_SEC_CNT_W / 2 - 2 + PnlTextW(cs, lpt) / 2,
                                 y + 16, cs, DSTRIP_CLR_TITLE, txt, lpt, true);
      }
      else
      {
         if(ObjectFind(0, cchip) >= 0) { ObjectDelete(0, cchip); dirty = true; }
         if(ObjectFind(0, clbl) >= 0) { ObjectDelete(0, clbl); dirty = true; }
      }
   }
   return dirty;
}
bool DrawStripGearPaint()
{
   bool dirty = false;
   int gx = DrawStripGearX();
   int cw = DrawStripGearCellW();   // P-DRAW-99: ONE column's cell — the owner
   int px = gx + DSTRIP_GEAR_PAD;
   dirty |= DrawStripGearHeadPaint();
   //--- P-DRAW-117 (2026-10-01) — THE TAB BAND IS RETIRED, AND THIS IS ITS SWEEP.
   //--- The track bed, the five tab buttons and the accent underline are objects the
   //--- TAB build painted and this one does not: a chart that upgrades under the panel
   //--- would keep a second nav standing under the group rows, and no painter here
   //--- would ever take them down (a name a previous build wrote is an ORPHAN — Touch
   //--- rule 2). They die by literal name on every paint: seven ObjectFinds, no write
   //--- once they are gone, and the family's own prefix wipe covers them on any close
   //--- or open that follows.
   if(ObjectFind(0, "PnlDrawS_GTrack") >= 0) { ObjectDelete(0, "PnlDrawS_GTrack"); dirty = true; }
   if(ObjectFind(0, "PnlDrawS_GU") >= 0) { ObjectDelete(0, "PnlDrawS_GU"); dirty = true; }
   for(int gt = 0; gt < DSTRIP_GEAR_GRP_MAX; gt++)
   {
      string tn = "PnlDrawS_GT" + IntegerToString(gt);
      if(ObjectFind(0, tn) >= 0) { ObjectDelete(0, tn); dirty = true; }
   }
   for(int g = 0; g < DSTRIP_GRID_MAX; g++)
   {
      string gn = DrawStripGridName(g), gi = DrawStripGridIconName(g);
      if(g >= s_dsGGN)
      {
         if(ObjectFind(0, gn) >= 0) { ObjectDelete(0, gn); dirty = true; }
         if(ObjectFind(0, gi) >= 0) { ObjectDelete(0, gi); dirty = true; }
         if(ObjectFind(0, DrawStripGridGlassName(g)) >= 0)
         { ObjectDelete(0, DrawStripGridGlassName(g)); dirty = true; }
         continue;
      }
      int cx = gx + s_dsGGX[g];
      int cy = s_dsGEY + s_dsGGY[g] + (DSTRIP_GEAR_ROW_H - s_dsGGH[g]) / 2;
      //--- P-DRAW-118 (2026-10-01): the grid carries the COLOUR ROLE ROWS too now.
      //--- A swatch cell's colour IS the cell (`s_dsGGC[g]`, written by the row's own
      //--- builder), and its skin is the strip's own `ds_swatch24` — the same face
      //--- the quick row's colour cell wears (P-DRAW-33), because the icon diet
      //--- removed the cards' glass at these sizes. The PREVIEW and the `+` are the
      //--- same act (open the board on this role), so one tooltip, one branch.
      {
         int slot = s_dsGGSlot[g], arg = s_dsGGArg[g], gk = s_dsGGKind[g];
         if(gk == DSTRIP_GRG_SWATCH)
         {
            color sc = s_dsGGC[g];
            string stip = "Color: " + DrawStripColorLabel(sc) + " — click to apply" + DrawStripTipScope();
            dirty |= DrawStripBtn(gn, cx, cy, s_dsGGW[g], s_dsGGH[g], sc, DrawStripInkOn(sc),
                                  (DrawStripColorRead(s_dsObj, slot) == sc) ? DSTRIP_CLR_ACCENT
                                                                           : BioSwatchBorder(sc, BIO_CLR_CARD),
                                  "", stip);
            dirty |= DrawStripFace(DrawStripGridGlassName(g), cx, cy, s_dsGGW[g], s_dsGGH[g],
                                   "::Files\\Icons\\ds_swatch24.bmp", stip);
         }
         else if(gk == DSTRIP_GRG_PREV || gk == DSTRIP_GRG_PLUS)
         {
            string otip = "Open the color picker" + DrawStripTipScope();
            if(gk == DSTRIP_GRG_PREV)
            {
               color oc = DrawStripColorRead(s_dsObj, slot);
               dirty |= DrawStripBtn(gn, cx, cy, s_dsGGW[g], s_dsGGH[g], oc, DrawStripInkOn(oc),
                                     BioSwatchBorder(oc, BIO_CLR_CARD), "", otip);
               dirty |= DrawStripFace(DrawStripGridGlassName(g), cx, cy, s_dsGGW[g], s_dsGGH[g],
                                      "::Files\\Icons\\ds_swatch24.bmp", otip);
               if(ObjectFind(0, gi) >= 0) { ObjectDelete(0, gi); dirty = true; }
            }
            else
            {
               dirty |= DrawStripBtn(gn, cx, cy, s_dsGGW[g], s_dsGGH[g], DSTRIP_CLR_FIELD,
                                     DSTRIP_CLR_LABEL, DSTRIP_CLR_FIELD_BD, "", otip);
               dirty |= DrawStripFace(gi, cx, cy, DSTRIP_GEAR_SWQ_PLUS, DSTRIP_GEAR_SWQ_PLUS,
                                      "::Files\\Icons\\gl_plus_m.bmp", otip);
            }
         }
         else
         {
            //--- P-DRAW-124 (2026-10-01) — A CELL THAT CHANGED ROLE TAKES ITS OLD
            //--- ROLE'S FACES WITH IT. The swatch and the chip ride the SAME grid
            //--- arrays, so one index is a colour cell on the Paint tab and a
            //--- width/style chip on the Style one — and only the FACES differ: the
            //--- swatch branch paints the glass (`ds_swatch24`) plus the glyph face
            //--- `gi`, and the chip branch below paints NEITHER and deleted neither,
            //--- so the previous tab's faces stayed standing at their old seat.
            //--- MEASURED live (2026-10-01 18:42:35, the report «این هنوز درست نشده»):
            //--- `GG0G..GG8G`, NINE 24x24 glass faces at y=186 — the PAINT tab's own
            //--- swatch row — while this tab's ten chips sit at y=224 and y=308, all
            //--- of them at z=1442, the LABELS' rung, over the band that shares that
            //--- row (the `STROKE` caption is at y=193). A face no branch of this
            //--- paint claims is exactly what P-DRAW-42 forbids: two probes here,
            //--- every paint, and the survivors go in the same frame the cell is
            //--- drawn as a chip (the PREV branch below already did this for `gi`).
            if(ObjectFind(0, DrawStripGridGlassName(g)) >= 0)
            { ObjectDelete(0, DrawStripGridGlassName(g)); dirty = true; }
            if(ObjectFind(0, gi) >= 0) { ObjectDelete(0, gi); dirty = true; }
            // P-DRAW-44: a chip — the width / line style / ray options.
            bool cur = DrawStripPickIsCur(s_dsObj, s_dsKind, slot, arg);
            string txt = PnlFit(DrawStripPickText(s_dsKind, slot, arg), 8, s_dsGGW[g] - 8);
            string tip = DrawStripPickTip(s_dsObj, s_dsKind, slot, arg);
            dirty |= DrawStripBtn(gn, cx, cy, s_dsGGW[g], s_dsGGH[g],
                                  cur ? DSTRIP_CLR_ACCENT : DSTRIP_CLR_FIELD,
                                  cur ? DSTRIP_CLR_ACCENTT : DSTRIP_CLR_LABEL,
                                  cur ? DSTRIP_CLR_ACCENT2 : DSTRIP_CLR_FIELD_BD, txt, tip);
         }
      }
   }
   dirty |= DrawStripGearSectionsPaint(px, cw);
   for(int r = 0; r < DSTRIP_GLIST_MAX; r++)
   {
      string rn = DrawStripRowName(r), ri = DrawStripRowIconName(r), rl = DrawStripRowLabelName(r);
      string rc = DrawStripRowChipName(r), rr = DrawStripRowRailName(r);
      string rs = DrawStripRowStateName(r), rp = DrawStripRowSepName(r);
      if(r >= s_dsGRN)
      {
         if(ObjectFind(0, rn) >= 0) { ObjectDelete(0, rn); dirty = true; }
         if(ObjectFind(0, ri) >= 0) { ObjectDelete(0, ri); dirty = true; }
         if(ObjectFind(0, rl) >= 0) { ObjectDelete(0, rl); dirty = true; }
         if(ObjectFind(0, rc) >= 0) { ObjectDelete(0, rc); dirty = true; }
         if(ObjectFind(0, rr) >= 0) { ObjectDelete(0, rr); dirty = true; }
         if(ObjectFind(0, rs) >= 0) { ObjectDelete(0, rs); dirty = true; }
         if(ObjectFind(0, rp) >= 0) { ObjectDelete(0, rp); dirty = true; }
         //--- P-DRAW-117: and the row's DIGEST — a retired row takes its value with
         //--- it, or a stale hex hangs over the row that replaced it.
         if(ObjectFind(0, DrawStripRowDigestName(r)) >= 0)
         { ObjectDelete(0, DrawStripRowDigestName(r)); dirty = true; }
         continue;
      }
      int py = s_dsGEY + s_dsGRY[r];
      int rx = px + s_dsGRCol[r] * DSTRIP_GEAR_COL;   // P-DRAW-30: this row's column
      bool cur = DrawStripGearRowIsCur(r);
      string res = DrawStripGearRowRes(r);
      string txt = DrawStripGearRowText(r);
      string tip = DrawStripGearRowTip(r);
      color ink = (s_dsGRKind[r] == 6 && !cur) ? DSTRIP_CLR_TITLE : DSTRIP_CLR_LABEL;
      //--- P-DRAW-69: the row's own face is its CELL — one tone, one owner, so it
      //--- cannot sit a unit off the band under it. The hairline above it is the
      //--- cell seam now (edge to edge, the cards' own), so this row's private 1px
      //--- stub is gone: it stopped 32px short of the plate and drew nothing at all
      //--- under a caption band, which is why COLOR/FILL and Interior read as two
      //--- different objects in one card.
      if(ObjectFind(0, rp) >= 0) { ObjectDelete(0, rp); dirty = true; }
      color rowTone = StrapCellTone(s_dsGRY[r], DSTRIP_BODY_TOP, DSTRIP_GEAR_GRID_TOP, s_dsGearH);
      dirty |= DrawStripBtn(rn, rx, py, cw, DSTRIP_GEAR_ROW_H, rowTone, ink, rowTone, "", tip);
      //--- P-DRAW-117 — A GROUP HEADER: icon, name, and the value it holds.
      //--- One muscle per face and no switch (a group is not a boolean): the chip is
      //--- the cards' own, gold while THIS group is the open one, the label is the
      //--- row's own ink (INK when open, LABEL when closed) and the digest is
      //--- right-aligned with `DSTRIP_GEAR_DG_PAD` of air to the cell's edge — the
      //--- label is fitted against it, so the two can never collide at any DPI.
      if(s_dsGRKind[r] == DSTRIP_GRK_GROUP)
      {
         string dg = PnlFit(DrawStripGearGroupDigest(s_dsGRArg[r]), 8, cw / 2);
         int dw = (dg == "") ? 0 : PnlTextW(dg, 8);
         dirty |= DrawStripFace(rc, rx + DSTRIP_GEAR_PAD, py + DSTRIP_CARD_CHIP_Y, 22, 22,
                                cur ? "::Files\\Icons\\pnl_chip_gold.bmp" : "::Files\\Icons\\pnl_chip.bmp", tip);
         dirty |= DrawStripFace(ri, rx + DSTRIP_GEAR_PAD, py + DSTRIP_CARD_CHIP_Y, 22, 22, res, tip);
         int gx0 = rx + DSTRIP_GEAR_PAD + 22 + 8;
         dirty |= DrawStripLblIn(rl, gx0, py, DSTRIP_GEAR_ROW_H,
                                 PnlFit(txt, 9, cw - (gx0 - rx) - dw - DSTRIP_GEAR_DG_PAD - DSTRIP_ROW_GAP),
                                 cur ? DSTRIP_CLR_VALUE : DSTRIP_CLR_LABEL, tip, 9, true);
         if(dw > 0)
            dirty |= DrawStripLblAt(DrawStripRowDigestName(r), rx + cw - DSTRIP_GEAR_DG_PAD - dw,
                                    StrapInkY(py, DSTRIP_GEAR_ROW_H, 8), dg,
                                    cur ? DSTRIP_CLR_ACCENT : DSTRIP_CLR_TITLE, tip, 8, true);
         else if(ObjectFind(0, DrawStripRowDigestName(r)) >= 0)
         { ObjectDelete(0, DrawStripRowDigestName(r)); dirty = true; }
         dirty |= DrawStripFace(rr, rx, py, 2, DSTRIP_GEAR_ROW_H,
                                cur ? "::Files\\Icons\\pnl_rail_gold.bmp" : "", tip);
         //--- and the SWITCH seat is not this row's: a stale one from a previous
         //--- tab (or a previous kind) is taken down here, the same rule the row's
         //--- own separator follows above.
         if(ObjectFind(0, rs) >= 0) { ObjectDelete(0, rs); dirty = true; }
         continue;
      }
      //--- P-DRAW-124: AND THE DIGEST IS THE GROUP'S OWN FACE. A row that was a
      //--- group header on the previous tab and is a switch on this one kept its
      //--- digest OBJECT: the group branch gives an empty digest the delete, the
      //--- switch branch below never asked the question at all. MEASURED live
      //--- (2026-10-01 18:42:35): `GR2D`/`GR3D`/`GR4D` still read `"3px · Solid"`
      //--- at (1310,360)/(1348,402)/(1334,444) — the PAINT tab's own digest seats
      //--- — at z=1442, the labels' rung, over whatever now shares that seat. The
      //--- row's value is the group's; a switch states its own state and nothing
      //--- else. One probe, on the path that is not a group.
      if(ObjectFind(0, DrawStripRowDigestName(r)) >= 0)
      { ObjectDelete(0, DrawStripRowDigestName(r)); dirty = true; }
      if(res != "" && !DrawStripGearLevelSwatch(r, rx, py, dirty))
      {
         //--- P-DRAW-77: THE CARDS' OWN SEATS, MEASURED, NOT DERIVED. The chip is
         //--- `px+PNL_PAD_X, ry+PNL_CHIP_Y` and the label `PnlLabelX()` = PAD_X +
         //--- CHIP_VIS + 8 at `ry+PNL_LBL_Y` (BiotakPanels 6155/6158) — this panel
         //--- sat them on a tighter 12/32 grid of its own, which is the whole of
         //--- "the panel reads as a second grid beside the cards".
         dirty |= DrawStripFace(rc, rx + DSTRIP_GEAR_PAD, py + DSTRIP_CARD_CHIP_Y, 22, 22,
                                cur ? "::Files\\Icons\\pnl_chip_gold.bmp" : "::Files\\Icons\\pnl_chip.bmp", tip);
         dirty |= DrawStripFace(ri, rx + DSTRIP_GEAR_PAD, py + DSTRIP_CARD_CHIP_Y, 22, 22, res, tip);
      }
      int labelX = rx + DSTRIP_GEAR_PAD + (res == "" ? 0 : 22 + 8);
      int k = s_dsGRKind[r];
      bool isSw = (k == 1 || k == 4 || k == 6);
      int stateW = isSw ? 40 : 20;          // PNL_SW_W 40 · the check/nav glyph 20
      //--- P-DRAW-68: the cards' own row label, weight included — `PnlPaintLabel`
      //--- writes Arial Bold at PNL_PT_LBL and this row sat in Arial regular, the
      //--- one font difference between the panel and the card it stands beside.
      dirty |= DrawStripLblIn(rl, labelX, py, DSTRIP_GEAR_ROW_H,
                              PnlFit(txt, 9, cw - (labelX - rx) - stateW - DSTRIP_ROW_GAP),
                              ink, tip, 9, true);
      dirty |= DrawStripFace(rr, rx, py, 2, DSTRIP_GEAR_ROW_H,
                             cur ? "::Files\\Icons\\pnl_rail_gold.bmp" : "", tip);
      string state = "";
      if(isSw)
         state = cur ? "::Files\\Icons\\pnl_sw_on_gold.bmp" : "::Files\\Icons\\pnl_sw_off.bmp";
      else if(cur && (k == 2 || k == 8))
         state = "::Files\\Icons\\gl_check_gold.bmp";
      else if(k == 3 || k == 5 || k == 7)
         state = "::Files\\Icons\\gl_nav_m.bmp";   // the level's own stepper
      //--- P-DRAW-77: the control sits on the cards' own seat — right-aligned
      //--- `px+PNL_SW_X` = contentW-40, at `ry+PNL_SW_Y` = +10, 40x22
      //--- (BiotakPanels 6160). The old `cw-18 / 15` was a narrower pill on a
      //--- different right inset, so the switch column read narrower than the
      //--- cards' beside it.
      dirty |= DrawStripFace(rs, rx + cw - (isSw ? 40 : 18), py + DSTRIP_CARD_CHIP_Y,
                             isSw ? 40 : 15, 22, state, tip);
   }
   for(int e = 0; e < 5; e++)
   {
      string en = DrawStripEditName(e);
      //--- P-DRAW-118 (2026-10-01): the two COLOUR seats (e0, e4) are RETIRED with
      //--- the hex boxes they typed into — a colour is a swatch now, and the exact
      //--- value is the board's HEX field (behind the row's `+`). Their objects die in
      //--- the `!want` branch below, which is the same sweep every retired field uses.
      bool want = ((e == 1 && s_dsGear == DSTRIP_GEAR_LEVELS) ||
                   (e == 2 && s_dsGear == DSTRIP_GEAR_MARK && s_dsKind == DK_TEXT) ||
                   (e == 3 && s_dsGear == DSTRIP_GEAR_TPL && s_dsTplNameArmed) ||
                   (e == 4 && s_dsGear == DSTRIP_GEAR_LEVELS && DrawStripLvlDescWant()));
      if(!want)
      {
         if(ObjectFind(0, en) >= 0) { ObjectDelete(0, en); dirty = true; }
         continue;
      }
      //--- P-DRAW-82: THE FIELD'S WIDTH IS THE CARD'S CONTENT BOX, NOT
      //--- `cw - seat`. `cw` here is `DSTRIP_GEAR_W - 2*PAD` = 280 measured from
      //--- `px` (the card + 16), so `cw - seat` double-counted the 16px pad: the
      //--- field ended 16px PAST the card's right edge on every wide hex row —
      //--- which is the field hanging off the card in the report. The field's own
      //--- right end is `cardRight - PAD`, one pad in, exactly like a card row's
      //--- control (PNL_SW_X = PNL_WEL-2*PNL_PAD_X = 280).
      int ex = px + s_dsGearEditCol[e] * DSTRIP_GEAR_COL + s_dsGearEditX[e];
      int ew = (s_dsGearEditW[e] > 0) ? s_dsGearEditW[e] : cw;
      //--- P-DRAW-118 (2026-10-01): the two colour seats are gone with their boxes
      //--- (see the `want` above); the three that remain are typed VALUES, not
      //--- readings, so none of them re-seeds itself while a hand is in it.
      //--- The board's own HEX field still follows the colour it states — that law is
      //--- `DrawStripPopHex`'s, and it is the one the retired panel boxes copied
      //--- (P-DRAW-100, whose site moved with the field).
      if(e == 1)
         dirty |= DrawStripEdit(e, ex, s_dsGearEditY[e], ew, "",
                                "Add a level, e.g. 88.6 — Enter adds it (the held drawing)", false);
      else if(e == 3)
         dirty |= DrawStripEdit(e, ex, s_dsGearEditY[e], ew, "",
                                "Template name — Enter saves this look under your name", false);
      else if(e == 4)
         dirty |= DrawStripEdit(e, ex, s_dsGearEditY[e], ew, ObjectGetString(0, s_dsObj, OBJPROP_LEVELTEXT, s_dsLvlDescIdx), "Level note — Enter writes it on this level", false);
      else
         dirty |= DrawStripEdit(e, ex, s_dsGearEditY[e], ew,
                                ObjectGetString(0, s_dsObj, OBJPROP_TEXT),
                                "Caption — Enter applies it", false);
   }
    //--- P-DRAW-80: THE FOOT IS THE CARDS' FOOT (BiotakPanels 6486-6507, 6901-6903).
    //--- LEFT-ALIGNED at `+16` and `+10` down, each button a 28px ghost with its
    //--- GLYPH at `bx+12` and its label at `bx+32` — the pair the cards wear. This
    //--- panel centred a bare word with no glyph at all, so its foot read as a row
    //--- of captions under a card that has two buttons with icons.
    int fy0 = s_dsGEY + s_dsGearFootY;
    //--- P-DRAW-90: the foot's own width is the COLUMN's (DrawStripGearColW), the
    //--- same answer the hit test reads — the local `cw` above is one 312 column's
    //--- 280 on EVERY tab, which would park the pair 312px short on a 624 one.
    int fcw = DrawStripGearColW();
    for(int f = 0; f < DSTRIP_GEAR_FOOT_N; f++)
    {
      string fn = DrawStripFootName(f);
      string label = DrawStripFootText(f);
      //--- P-DRAW-80: the cards' OWN width formula (BiotakPanels 6481-6484) —
      //--- `max(72, 32 + advance + 8)`, owned by DrawStripFootBw (P-DRAW-90: the
      //--- hit test spends the same function, never a second arithmetic).
      int bw = DrawStripFootBw(f);
      int fx = DrawStripFootX(f, px, fcw);
      int fy = fy0 + 10;
      string tip = DrawStripFootTip(f);
      color ink = DSTRIP_CLR_TITLE;                       // = BIO_CLR_MUTED
      dirty |= DrawStripBtn(fn, fx, fy, bw, 28, DSTRIP_CLR_FOOT,
                            DSTRIP_CLR_FOOT, DSTRIP_CLR_FOOT, "", tip);
      dirty |= DrawStripFace(DrawStripFootSkinName(f), fx - 8, fy - 8,
                             bw + 16, 44,
                             "::Files\\Icons\\pnl_btn_ghost.bmp", tip);
      //--- the card's own glyph seat, 15x15 on Z_PANEL_INK; one glyph per action
      //--- (the cards give Reset a reset ring and Done a check, PnlFooterBtn's
      //--- `ico` argument, BiotakPanels 6901-6902). P-DRAW-90: `Reset` is the one
      //--- the design gives a glyph — DrawStripFootRes answers "" for the pair,
      //--- and DrawStripFaceZ DELETES on "", which is the sweep for the ring the
      //--- old two-button foot wore on `All`.
      //--- P-DRAW-107: BOTH seats come from the one centred group above — the paint
      //--- asks for `fgx` and `lx` and derives neither (`gx` is the GEAR PLATE's own
      //--- left edge in this function — a shadowed name here is a second meaning for
      //--- one word). `fx + 12` (the cards' own glyph seat) is what stood here, and on
      //--- a plate this narrow it was the left half of a left-aligned pair.
      int lx = DrawStripFootLabelX(f, fx);
      int fgx = DrawStripFootGlyphX(f, fx);
      dirty |= DrawStripFace(DrawStripFootGlyphName(f), fgx, fy + 6, 15, 15,
                             DrawStripFootRes(f), tip);
      dirty |= DrawStripLblIn(DrawStripFootLabelName(f), lx, fy, 28,
                              PnlFit(label, 8, fx + bw - 8 - lx),
                              ink, tip, 8, true);
   }
   //--- P-DRAW-78: the retired third button (`Del`) dies here, not in the purge
   //--- above — this loop is the only other writer of the GF family, and without
   //--- a stale branch a chart that wore the 3-button foot keeps a dead Del.
   //--- Bounded: exactly the one retired seat.
   //--- P-DRAW-90: and it is EMPTY again, by construction — `Del`'s seat 2 is
   //--- `Copy`'s now (`DSTRIP_GEAR_FOOT_N` is 3), so seats 0..2 are all live and
   //--- the loop runs zero times. It stays as the family's guard, and its bound
   //--- still names the highest seat this family has ever owned (3). A chart that
   //--- wore the old two-button foot needs no sweep either: seat 2 was never
   //--- written then, and seat 1's stale `gl_check_gold` ring is deleted by the
   //--- paint itself (DrawStripFootRes -> "" -> DrawStripFaceZ deletes).
   for(int fd = DSTRIP_GEAR_FOOT_N; fd < 3; fd++)
   {
      //--- P-DRAW-84: ...and its GLYPH, which is a member of the same family
      //--- (`DrawStripFootGlyphName`) and was not in this list either — the same
      //--- partial-delete shape as the band family above, one seat over.
      if(ObjectFind(0, DrawStripFootName(fd)) >= 0)
      { ObjectDelete(0, DrawStripFootName(fd)); dirty = true; }
      if(ObjectFind(0, DrawStripFootSkinName(fd)) >= 0)
      { ObjectDelete(0, DrawStripFootSkinName(fd)); dirty = true; }
      if(ObjectFind(0, DrawStripFootGlyphName(fd)) >= 0)
      { ObjectDelete(0, DrawStripFootGlyphName(fd)); dirty = true; }
      if(ObjectFind(0, DrawStripFootLabelName(fd)) >= 0)
      { ObjectDelete(0, DrawStripFootLabelName(fd)); dirty = true; }
   }
   return dirty;
}

//--- purge every gear object (gear shut).
bool DrawStripGearPurge()
{
   if(s_dsGearHeadY < 0 && s_dsGRN <= 0 && s_dsGGN <= 0) return false;
   return DrawStripGearObjectsPurge();
}
#endif // DRAW_STRIP_GEARB_MQH
// DrawStrip_Skin.mqh - DrawStrip split 2026-09-29: exact lines 4407-5338 of DrawStrip.mqh, byte-identical, zero renames.
#ifndef DRAW_STRIP_SKIN_MQH
#define DRAW_STRIP_SKIN_MQH


//--- P-DRAW-29 (2026-09-24) — THE PLATE WEARS THE CARDS' OWN SKIN. User order:
//--- «کل ظاهر پنل مثل بقیه بشه». The flat rectangle is retired for a 9-slice of
//--- the panels' own Obsidian-Gold surface (margin 14, radius 10, 1px #2C3444
//--- border, drop shadow, top catchlight — tools/gen-th3-icons.js `ds_*`): the
//--- plate's height is ALWAYS 48+36k (quick row + k bands on the CELL+GAP grid,
//--- DrawStripLayout's own arithmetic), so one top cap (margin + 44) + k mid
//--- bands (36) + one bottom cap (4 + margin) composes every height, and the
//--- middles crop to every width (MT4 crops a smaller XSIZE/YSIZE, never
//--- stretches — each middle is uniform along its crop axis, so the crop is
//--- invisible). The mid-row centre is a plain DSTRIP_CLR_PANEL rect (flat
//--- mid-tone, one level off the baked ramp — invisible). A plate that cannot
//--- be skinned (taller than 24 bands, wider than 660) keeps the legacy rect,
//--- so an unmeasurable layout never draws a half plate. (Metrics live with
//--- the V6 shell metrics above: MQL4 is define-before-use.)
string DrawStripSkinName(const int i)
{
   switch(i)
   {
      case 0: return "PnlDrawS_BGtL";
      case 1: return "PnlDrawS_BGtM";
      case 2: return "PnlDrawS_BGtR";
      case 3: return "PnlDrawS_BGmL";
      case 4: return "PnlDrawS_BGmM";
      case 5: return "PnlDrawS_BGmR";
      case 6: return "PnlDrawS_BGbL";
      case 7: return "PnlDrawS_BGbM";
      case 8: return "PnlDrawS_BGbR";
   }
   return "";
}
//--- P-DRAW-32: the SETTINGS PANEL'S OWN nine pieces. One baker, one skin, two
//--- plates — the family index is the whole difference.
string DrawStripGearSkinName(const int i)
{
   switch(i)
   {
      case 0: return "PnlDrawS_GBtL";
      case 1: return "PnlDrawS_GBtM";
      case 2: return "PnlDrawS_GBtR";
      case 3: return "PnlDrawS_GBmL";
      case 4: return "PnlDrawS_GBmM";
      case 5: return "PnlDrawS_GBmR";
      case 6: return "PnlDrawS_GBbL";
      case 7: return "PnlDrawS_GBbM";
      case 8: return "PnlDrawS_GBbR";
   }
   return "";
}
//--- P-DRAW-48 (2026-09-26) — THE BOARD'S OWN NINE PIECES, and they must be its
//--- own. `DrawStripSkinPiece` answered the STRIP's names for family 2, so the two
//--- plates were ONE set of objects: the strip's plate (height 48, k = 0) deletes
//--- the mid pieces on every paint and the board's plate (k = 10) re-created them
//--- as the NEWEST objects at Z_STRIP_ICON — i.e. over the board's 64 cells, its
//--- RECENT band and its HEX field. Measured on the reported chart: the board's
//--- whole body was ONE colour at 24,750 samples. One plate, one name.
string DrawStripBoardSkinName(const int i)
{
   switch(i)
   {
      case 0: return "PnlDrawS_BBtL";
      case 1: return "PnlDrawS_BBtM";
      case 2: return "PnlDrawS_BBtR";
      case 3: return "PnlDrawS_BBmL";
      case 4: return "PnlDrawS_BBmM";
      case 5: return "PnlDrawS_BBmR";
      case 6: return "PnlDrawS_BBbL";
      case 7: return "PnlDrawS_BBbM";
      case 8: return "PnlDrawS_BBbR";
   }
   return "";
}
//--- P-DRAW-89 (2026-09-29) — THE PLATE'S TRANSPARENCY IS RETIRED. User order:
//--- «این شفافیت پنل به کل حذف کن لازم نیستش». It was not a tint: with
//--- `s_dsPlateTIdx > 0` the underlayer stopped being a PANEL tone and became the
//--- CHART's own background (`DrawStripPlateFill` -> `GetCachedChartBgColor`), and
//--- `StrapBodyTone` returned that same raw colour for every cell. So the whole
//--- surface — track, rows, cells, grips — took one colour off `CHART_COLOR_BACKGROUND`:
//--- cyan on the dark template, magenta-blue on the light one. MEASURED, the panel
//--- census on 2026-09-29 11:29 read `PnlDrawS_GTrack bgcolor=-16924895` =
//--- `0xFEFDBF21` = R33 G191 B253, a value that exists in no palette and in no
//--- painter here — it was the chart's own. The four tabs beside it read 2892317
//--- (the card tone) because they are painted from a constant, not from the tone
//--- chain, which is exactly why only the tone-driven surfaces went wrong.
//---
//--- Why deletion and not a blend: a blend still asks the chart for a colour, and the
//--- chart's background is a USER choice (a template, a preset, a light theme) that
//--- the panel must never depend on. One look, one owner, zero chart reads on this
//--- surface. The `_t30/60/90.bmp` sets go with it — nothing asks for them any more.
int    DrawStripPlateT()      { return 0; }
int    DrawStripPlateTPct()   { return 0; }
void   DrawStripPlateTSet(const int i) { /* retired: the plate has one look */ }
string DrawStripSkinRes(const string base)
{
   return "::Files\\Icons\\" + base + ".bmp";
}
//--- P-PAL-17 (2026-10-02) — FAMILY 2 WEARS ITS OWN NINE. The strip and the
//--- settings panel keep the shipped `ds_*` art (byte-identical to what shipped);
//--- the colour board reads `ds_pb_*`, baked at the modern corner so the box speaks
//--- the same recipe as the cells inside it. A per-family base is the whole change:
//--- nine `DrawStripSkinResFor(fam, …)` calls where nine literals stood.
string DrawStripSkinResFor(const int fam, const string base)
{
   return DrawStripSkinRes((fam == 2) ? ("ds_pb_" + base) : ("ds_" + base));
}
//--- the underlayer behind the skin: the panel tone when the plate is solid, the
//--- chart's own background when it is translucent — which is what keeps P-DRAW-35's
//--- white-chart fringe fix while letting the chart show through the plate.
color DrawStripPlateFill()
{
   //--- P-DRAW-89: the chart's background is NEVER this panel's colour. It used to
   //--- be one of two answers, and on a light template the whole surface went
   //--- chart-coloured. One look, one owner.
   return DSTRIP_CLR_PANEL;
}

//--- P-DRAW-69 — THE 42px CELL IS THE ONLY GRID, AND ONE CELL IS ONE TONE. The
//--- cards bake ONE body with a hairline at every row seam and NO per-row face
//--- (measured on `pnl_card7.bmp`: the body reads the same (24,29,38) at x=20, 100,
//--- 170, 240, 300, and the seam rows 69/70 read #222832 edge to edge). This panel
//--- had TWO grids: the bands split the body into 6, and every row drew its own
//--- face at the ramp's own centre — which lands 1 RGB unit off the band beneath it
//--- (row 98 -> (22,26,35); the band [93,142] -> (22,27,35)), so every row read as
//--- its own plate. The bands now ride the SURFACE's cell grid and the cells are
//--- 42px, so a row's face IS its band and the plate reads as one glass.
#define DSTRIP_BODY_MAX 40      // cells + the head and tail bands (k <= 24)
#define DSTRIP_SEAM_H    2       // the card's own seam is 2 rows of white @ 5.5 %
//--- P-DRAW-70 — THE RAMP IS THE CARD'S, PARAMETERISED BY THE SURFACE'S OWN HEIGHT.
//--- `BioCardTone(t)` IS `cardGrad(t)` in tools/gen-th3-icons.js, and the card bakes
//--- it as `cardGrad(cy / H)` over the WHOLE card: TOP at 0 %, MID at 52 %, BOT at
//--- 100 %. This function handed it `0.52 + 0.48·t` instead — it kept only the ramp's
//--- LOWER half and stretched it over the body, so a plate hit CARD_MID four times
//--- too early and sat 5-10 RGB units under the card at every height. Measured on the
//--- Paint tab (plate 342) against `pnl_card7.bmp` (content 398), same fraction:
//---   old  plate content 119 -> (22,26,35)   card at 119/398 -> (27,33,43)
//---   new  plate content 119 -> (25,31,40)   card at 119/398 -> (25,31,40)
color StrapBodyTone(const int dy, const int bandH, const int plateH)
{
   //--- P-DRAW-89: the tone is a TONE. It was short-circuited to the chart's own
   //--- background whenever the plate was translucent, which is how the tab track
   //--- came out cyan (measured -16924895 = 0xFEFDBF21) on a dark template. A
   //--- still plate falls back to the panel tone; a moving one always reads the ramp.
   if(plateH <= 0) return DSTRIP_CLR_PANEL;
   double t = ((double)dy + bandH * 0.5) / (double)plateH;
   if(t < 0.0) t = 0.0;
   if(t > 1.0) t = 1.0;
   return BioCardTone(t);
}
//--- the tone of the CELL that owns `contentY` — the ONE answer a row, a popover
//--- row, the tab track and the band under them all ask, so two owners can never
//--- disagree by a unit (H-06). Above `gridTop` is the head's own single band.
color StrapCellTone(const int contentY, const int bodyTop, const int gridTop, const int plateH)
{
   if(contentY < gridTop) return StrapBodyTone(bodyTop, gridTop - bodyTop, plateH);
   int cell = contentY - ((contentY - gridTop) % DSTRIP_SKIN_MID);
   return StrapBodyTone(cell, DSTRIP_SKIN_MID, plateH);
}
//--- the seat's ring wears the BORDER colour while it reads against the plate, else
//--- the legibility floor's own outline (catalogue 1: an invisible ring is the
//--- "empty slot"). `BioSwatchBorder` answers the same question with a neutral
//--- outline, which is why the ring cannot reuse it verbatim.
color StrapRingInk(const color c, const color backdrop)
{
   return (BioContrast(c, backdrop) < BIO_SWATCH_MIN_CONTRAST) ? BIO_CLR_MUTED : c;
}
//--- the body's bands: one name per band per family, and band 0 IS the shipped
//--- body object (piece 4), so an older build's plate cannot leave a ghost.
string DrawStripBodyName(const int fam, const int b)
{
   string base = DrawStripSkinPiece(fam, 4);
   return (b == 0) ? base : base + "B" + IntegerToString(b);
}
//--- P-DRAW-69: the seam rides the CELL, so the bands and the rules are one walk and
//--- one owner. Its name carries the plate's own prefix, so `DrawStripIsBg` reads a
//--- tap on it as a tap on the plate (P-DRAW-11) instead of a dead pixel.
string DrawStripSeamName(const int fam, const int b)
{
   return DrawStripBodyName(fam, b) + "S";
}
//--- one cell: its flat tone (the cards have no per-row face) and, from `seamFrom`
//--- down, the card's own 2px hairline at the cell's top edge, edge to edge.
bool DrawStripCellPaint(const int fam, const int b, const int plateTop, const int plateH,
                        const int x, const int y, const int w, const int h,
                        const int seamFrom)
{
   color tone = StrapBodyTone(y - plateTop, h, plateH);
   bool dirty = DrawStripBtnZ(DrawStripBodyName(fam, b), x, y, w, h,
                              tone, tone, tone, "", "", Z_STRIP);
   int cy = y - plateTop;
   if(cy >= seamFrom && seamFrom >= 0)
      dirty |= DrawStripRect(DrawStripSeamName(fam, b), x - 1, y,
                             w + 2, DSTRIP_SEAM_H,
                             DSTRIP_CLR_LINE, Z_STRIP_ICON);
   return dirty;
}
//--- P-DRAW-70: `bodyTop` is where this surface's ramp starts — DSTRIP_BODY_TOP (2,
//--- the card's own first body row) for the two cards, and the baked cap's content
//--- bottom (44) for the strip's 48px quick row, which is a TOOLBAR and keeps the
//--- shipped cap ramp. A card that starts its body at 44 wears the cap's own 44px
//--- CARD_TOP->CARD_MID walk on top of the card's ramp, which is the 5-10 unit hole.
bool DrawStripBodyPaint(const int fam, const int plateTop, const int plateH,
                        const int x, const int y, const int w, const int h,
                        const int gridTop, const int seamFrom)
{
   bool dirty = false;
   int b = 0, y0 = y, yEnd = y + h;
   int headBot = DSTRIP_SKIN_TOPT - DSTRIP_SKIN_M;
   if(gridTop > y0 && gridTop < yEnd)
   {
      dirty |= DrawStripCellPaint(fam, b++, plateTop, plateH, x, y0, w, gridTop - y0, seamFrom);
      y0 = gridTop;
   }
   while(y0 < yEnd && b < DSTRIP_BODY_MAX - 1)
   {
      int y1 = y0 + DSTRIP_SKIN_MID;
      if(y1 > yEnd) y1 = yEnd;
      dirty |= DrawStripCellPaint(fam, b++, plateTop, plateH, x, y0, w, y1 - y0, seamFrom);
      y0 = y1;
   }
   if(y0 < yEnd)   // the tail: the foot and the plate's own air, one band
      dirty |= DrawStripCellPaint(fam, b++, plateTop, plateH, x, y0, w, yEnd - y0, seamFrom);
   for(int t = b; t < DSTRIP_BODY_MAX; t++)
   {
      string nm = DrawStripBodyName(fam, t);
      if(ObjectFind(0, nm) >= 0) { ObjectDelete(0, nm); dirty = true; }
      string sn = DrawStripSeamName(fam, t);
      if(ObjectFind(0, sn) >= 0) { ObjectDelete(0, sn); dirty = true; }
   }
   return dirty;
}
bool DrawStripBodyPurge(const int fam)
{
   bool dirty = false;
   for(int b = 0; b < DSTRIP_BODY_MAX; b++)
   {
      string nm = DrawStripBodyName(fam, b);
      if(ObjectFind(0, nm) >= 0) { ObjectDelete(0, nm); dirty = true; }
      string sn = DrawStripSeamName(fam, b);
      if(ObjectFind(0, sn) >= 0) { ObjectDelete(0, sn); dirty = true; }
   }
   return dirty;
}

//--- 0 = the strip's plate · 1 = the settings panel's plate (P-DRAW-32).
string DrawStripSkinPiece(const int fam, const int i)
{
   return (fam == 1 ? DrawStripGearSkinName(i)
                    : (fam == 2 ? DrawStripBoardSkinName(i) : DrawStripSkinName(i)));
}
//--- the plate is a FAMILY now (9 skin pieces, or the legacy rect): a tap on
//--- any of them is a tap on the plate (P-DRAW-11's popover rule). P-DRAW-32: the
//--- SETTINGS PANEL's plate and its section bands belong to the same family, so a
//--- tap on the panel's own surface never reads as a tap on the chart.
bool DrawStripIsBg(const string nm)
{
//--- P-DRAW-83: THE PANEL'S OWN PLATE IS THE PANEL'S PLATE. `DrawStripGearBgName()`
   // ("PnlDrawS_GBG", the retired underlayer) matched here by the letter B, while
   // the plate this build really paints — "PnlDrawS_Gbake" / "Gtop" / "Gmid*" /
   // "Gbot" — differs by the case of that one letter and matched NOTHING. With the
   // plate back under its controls (see DrawStripGearPlate) that means the panel's
   // own margins, padding and air are pixels no control owns: a press there fell
   // past every branch of the router and out to the CHART, which is the half of
   // P-DRAW-32's rule ("a tap on the panel's own surface never reads as a tap on the
   // chart") the spelling left open. Case-sensitive, and no control name
   // begins `Gb`: GT/GG/GR/GF/GE/GS/GU/GH and the tab bed keep their own owners.
   //--- P-DRAW-114 (2026-10-01) — AND THE SAME SPELLING WAS WRONG FOR THE WIDE PLATE,
   //--- WHICH IS THE WHOLE BUG ON THE TWO TABS THAT MATTER. The `Gb` term above matches
   //--- `PnlDrawS_Gb*` — the NARROW bake AND the wide body's own `Gbot` (both are
   //--- `PnlDrawS_G` + a lowercase `b`), so those two were never the gap. The gap is
   //--- the other TWO pieces: a tab whose height is off the card set composes its plate
   //--- out of three instead (DrawStripGearPlate: "PnlDrawS_Gtop" 745,
   //--- "PnlDrawS_Gmid<0..11>" 752, "PnlDrawS_Gbot" 758), and `Gt` / `Gm` matched
   //--- nothing at all.
   //--- MEASURED: Style and Row are the only two tabs that take that branch
   //--- (`PLATE tab=1/4 ... branch=wide obj=PnlDrawS_Gtop` in every 2026-10-01 log
   //--- line), so on exactly those two tabs the panel's own body — three opaque
   //--- tiles, the largest click targets it owns — was not its surface: the press
   //--- fell past the `DrawStripIsBg` branch (DrawStrip_Router.mqh:732), past every
   //--- name loop below it, and out to the chart. Paint is unaffected by construction
   //--- (its plate is `Gbake`), which is why the report reads as a Style/Row fault.
   //--- `Gt` / `Gm` are safe to claim for the plate and nothing else: the controls are
   //--- GT (tabs), GG (chips), GR (rows), GF (foot), GE (fields), GS (bands),
   //--- GU (underline), GH (head) and `GTrack` — a different letter, or UPPERCASE.
   return (StringFind(nm, "PnlDrawS_BG") == 0 ||
           StringFind(nm, "PnlDrawS_Gb") == 0 ||   // Gbake (narrow) + Gbot (wide)
           StringFind(nm, "PnlDrawS_Gt") == 0 ||   // P-DRAW-114: the wide plate's top cap
           StringFind(nm, "PnlDrawS_Gm") == 0 ||   // P-DRAW-114: ...its mid tiles
           StringFind(nm, "PnlDrawS_BB") == 0 ||   // P-DRAW-48: the board's own plate
           StringFind(nm, "PnlDrawS_GB") == 0 ||   // the retired nine-slice family
           StringFind(nm, "PnlDrawS_GH") == 0 ||
           StringFind(nm, "PnlDrawS_GS") == 0 ||
           StringFind(nm, "PnlDrawS_GU") == 0);
}
//--- P-DRAW-48: which of those plates is the COLOUR BOARD's own (`BB…`, one letter
//--- apart from the strip's `BG…`). It is the one surface that must not shut the
//--- popover it belongs to — its body is the space between its own cells.
bool DrawStripIsBoardPlate(const string nm)
{
   return (StringFind(nm, "PnlDrawS_BB") == 0);
}
//--- mid bands below the plate's own top zone, from that plate's height
//--- (-1: this height is off the skin's own 48 + 42k grid).
int DrawStripSkinKFor(const int h)
{
   if(h < 48) return -1;
   int k = (h - 48) / DSTRIP_SKIN_MID;
   if(k < 0 || k > DSTRIP_SKIN_MAXK || 48 + k * DSTRIP_SKIN_MID != h) return -1;
   return k;
}
bool DrawStripSkinFitsFor(const int w, const int h)
{
   int k = DrawStripSkinKFor(h);
   return (k >= 0 && w > 0 && w <= DSTRIP_SKIN_MAXW &&
           w + 2 * DSTRIP_SKIN_M - 2 * DSTRIP_SKIN_CAP <= DSTRIP_SKIN_MIDW);
}
//--- P-PAL-17: the CAP the board's own bake needs: margin 14 + its modern 16px
//--- corner, where the strip's nine are margin 14 + 14. ONE owner, and the painter
//--- asks it for all six cap reads (three widths, three x) — a second literal here
//--- is a corner blitted 2px off its own cap (P-DRAW-68's class).
int DrawStripSkinCap(const int fam) { return (fam == 2) ? 30 : DSTRIP_SKIN_CAP; }
//--- P-PAL-17 (2026-10-02) — THE BOARD'S PLATE IS NOT ON THE 42-BAND GRID. The
//--- strip and the settings panel are baked strips whose middles are WHOLE 42px
//--- bands, so their heights must be `48 + k*42` (P-PAL-08's measurement). The
//--- colour board's height is a SUM of bands that are not multiples of 42, and the
//--- snap to the next band was the dead black block under HEX the report shows: up
//--- to 41px of plate carrying nothing. Its nine pieces are CROPPED, not stretched
//--- (P-DRAW-29 — MT4 crops a smaller XSIZE/YSIZE and never stretches), so the board
//--- can take its MEASURED height and its plate ends exactly where HEX ends. The
//--- width law is unchanged: a wider plate would need a wider middle bake.
//--- ONLY family 2 reads this; the strip's and the panel's own grid is untouched.
bool DrawStripSkinFitsForFam(const int fam, const int w, const int h)
{
   if(fam != 2) return DrawStripSkinFitsFor(w, h);
   int cap = DrawStripSkinCap(fam);
   return (h >= DSTRIP_SKIN_TOPT + DSTRIP_SKIN_BOTT && w > 0 && w <= DSTRIP_SKIN_MAXW &&
           w + 2 * DSTRIP_SKIN_M - 2 * cap <= DSTRIP_SKIN_MIDW);
}
int  DrawStripSkinK()     { return DrawStripSkinKFor(s_dsH); }
bool DrawStripSkinFits()  { return DrawStripSkinFitsFor(s_dsW, s_dsH); }
//--- one skin bitmap: created once with the rung's face, guarded after (the
//--- module's write law — every ObjectSet* repaints at the chart's object
//--- count, so a write of a value already there is pure loss).
bool DrawStripSkinBmp(const string nm, const int x, const int y, const int w,
                      const int h, const string res, const int z = Z_STRIP)
{
   bool dirty = false;
   if(ObjectFind(0, nm) < 0)
   {
      if(!ObjectCreate(0, nm, OBJ_BITMAP_LABEL, 0, 0, 0)) return false;
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetInteger(0, nm, OBJPROP_STATE, false);
      ObjectSetInteger(0, nm, OBJPROP_ZORDER, z);
      ObjectSetString(0, nm, OBJPROP_TOOLTIP, "");
      dirty = true;
   }
   else
   {
      //--- the z is a write-on-create fact otherwise: a plate that was painted as
      //--- family 0 (Z_STRIP) and is now painted as a CARD must be re-asserted,
      //--- or the card keeps sitting UNDER the strip's own chrome. One compare.
      dirty |= DrawStripSetInt(nm, OBJPROP_ZORDER, z);
   }
   dirty |= DrawStripSetStr2(nm, OBJPROP_BMPFILE, 0, res);
   dirty |= DrawStripSetStr2(nm, OBJPROP_BMPFILE, 1, res);
   dirty |= DrawStripSetInt(nm, OBJPROP_XDISTANCE, x);
   dirty |= DrawStripSetInt(nm, OBJPROP_YDISTANCE, y);
   dirty |= DrawStripSetInt(nm, OBJPROP_XSIZE, w);
   dirty |= DrawStripSetInt(nm, OBJPROP_YSIZE, h);
   return dirty;
}
//--- delete one skin family (teardown law: by prefix family, 100%).
//--- P-DRAW-42 (2026-09-25) — AND THE FAMILY'S OWN BG RECT. Reported: a flat dark
//--- rectangle the size of the settings panel left on the chart with nothing on it.
//--- P-DRAW-35 made `PnlDrawS_BG`/`PnlDrawS_GBG` a permanent underlayer, and a purge
//--- that took the 9 tiles but not the underlayer left exactly that rectangle — the
//--- plate is ONE surface, so its one owner takes both, for both families.
bool DrawStripSkinPurgeAt(const int fam)
{
   bool dirty = false;
   for(int i = 0; i < 9; i++)
   {
      string nm = DrawStripSkinPiece(fam, i);
      if(ObjectFind(0, nm) >= 0) { ObjectDelete(0, nm); dirty = true; }
   }
   dirty |= DrawStripBodyPurge(fam);   // P-DRAW-67: the body's bands go with it
   if(fam == 1)
   {
      // pnl_card* path: also purge the bot-cap and the extended mid tiles (GBm9..11)
      string bc = DrawStripGearSkinName(0) + "Bot";
      if(ObjectFind(0, bc) >= 0) { ObjectDelete(0, bc); dirty = true; }
      for(int mi = 9; mi < DSTRIP_GEAR_BLK_MAX; mi++)
      {
         string mn = "PnlDrawS_GBm" + IntegerToString(mi);
         if(ObjectFind(0, mn) >= 0) { ObjectDelete(0, mn); dirty = true; }
      }
   }
   string bg = (fam == 1 ? DrawStripGearBgName()
                         : (fam == 2 ? DrawStripBoardBgName() : DrawStripBgName()));
   if(ObjectFind(0, bg) >= 0) { ObjectDelete(0, bg); dirty = true; }
   return dirty;
}
//--- P-DRAW-32: BOTH plates die together — a close (or a hide) owns the whole
//--- surface, and a family left behind is the ghost this project keeps paying for.
bool DrawStripSkinPurge()
{
   bool dirty = DrawStripSkinPurgeAt(0);
   dirty |= DrawStripSkinPurgeAt(1);
   dirty |= DrawStripSkinPurgeAt(2);   // P-DRAW-48: the colour board's own plate
   return dirty;
}
bool DrawStripGearSkinPurge()
{
   return DrawStripSkinPurgeAt(1);
}
//--- P-DRAW-32: ONE 9-slice painter, TWO plates. `fam` picks the family (the strip
//--- or the settings panel); the rect is the caller's, so the panel's plate can no
//--- longer be the strip's plate growing.
//--- P-LOG-10 (2026-10-02): raised when a 9-slice plate (strip fam 0, board fam 2)
//--- is purged by !DrawStripSkinFitsFor while its content survives. DrawStripPaint
//--- answers it at the TOP of the next pass — one purge before ANY painter runs —
//--- because a plate born after its content covers it (creation order is paint
//--- order; ZORDER rules clicks alone; a same-pixel write raises nothing).
bool s_dsSkinPlateDied = false;

bool DrawStripSkinPaintAt(const int fam, const int x, const int y, const int w, const int h,
                          const int gridTop, const int seamFrom, const int bodyTop)
{
   bool dirty = false;
   if(!DrawStripSkinFitsForFam(fam, w, h))
   {
      dirty |= DrawStripSkinPurgeAt(fam);
      s_dsSkinPlateDied = true;   // P-LOG-10: the content outlived its plate — the next paint purges before it paints
      return dirty;
   }
   //--- P-PAL-17: the middle is the MEASURED remainder (k*42 on the other two
   //--- families, h - top - bottom here), so the plate ends where the content does.
   int midH = (fam == 2) ? (h - DSTRIP_SKIN_TOPT - DSTRIP_SKIN_BOTT) : DrawStripSkinKFor(h) * DSTRIP_SKIN_MID;
   int cap = DrawStripSkinCap(fam);
   int sx = x - DSTRIP_SKIN_M, sy = y - DSTRIP_SKIN_M;
   int TW = w + 2 * DSTRIP_SKIN_M;
   int midW = TW - 2 * cap;
   int midY = sy + DSTRIP_SKIN_TOPT;
   int botY = midY + midH;
   color fill = DrawStripPlateFill();   // P-DRAW-43: solid tone, or the chart's own bg
   dirty |= DrawStripSkinBmp(DrawStripSkinPiece(fam, 0), sx, sy,
                             cap, DSTRIP_SKIN_TOPT,
                             DrawStripSkinResFor(fam, "top_l"));
   dirty |= DrawStripSkinBmp(DrawStripSkinPiece(fam, 1), sx + cap, sy,
                             midW, DSTRIP_SKIN_TOPT, DrawStripSkinResFor(fam, "top_m"));
   dirty |= DrawStripSkinBmp(DrawStripSkinPiece(fam, 2), sx + TW - cap, sy,
                             cap, DSTRIP_SKIN_TOPT,
                             DrawStripSkinResFor(fam, "top_r"));
   if(midH > 0)
   {
      dirty |= DrawStripSkinBmp(DrawStripSkinPiece(fam, 3), sx, midY,
                                DSTRIP_SKIN_EDGE, midH, DrawStripSkinResFor(fam, "mid_l"));
      // P-DRAW-48: the plate's own body — Z_STRIP, never the cells' layer.
      // P-DRAW-67: and it is the cards' RAMP now, band by band (see StrapBodyTone).
      // P-DRAW-69: on the SURFACE's own 42px cell grid, one flat tone per cell plus
      // P-DRAW-70: from `bodyTop` — the card's ramp covers the cap's own rows too.
      int bodyBot = y + h - (DSTRIP_SKIN_BOTT - DSTRIP_SKIN_M);
      if(bodyBot > y + bodyTop)
         dirty |= DrawStripBodyPaint(fam, y, h, sx + DSTRIP_SKIN_EDGE, y + bodyTop,
                                     TW - 2 * DSTRIP_SKIN_EDGE, bodyBot - bodyTop,
                                     gridTop, seamFrom);
      dirty |= DrawStripSkinBmp(DrawStripSkinPiece(fam, 5), sx + TW - DSTRIP_SKIN_EDGE, midY,
                                DSTRIP_SKIN_EDGE, midH, DrawStripSkinResFor(fam, "mid_r"));
   }
   else
   {
      for(int i = 3; i <= 5; i++)
      {
         // P-UI-34 (2026-09-25): was DrawStripSkinName(i) — always family 0.
         // When fam==1 (gear panel) the mid pieces are family 1 names, so the
         // family-0 names were never deleted and their stale OBJ_BUTTONs stayed
         // on the chart wearing the OS default (white) background.
         string nm = DrawStripSkinPiece(fam, i);
         if(ObjectFind(0, nm) >= 0) { ObjectDelete(0, nm); dirty = true; }
      }
      dirty |= DrawStripBodyPurge(fam);   // P-DRAW-67: a 48px plate has no body
   }
   dirty |= DrawStripSkinBmp(DrawStripSkinPiece(fam, 6), sx, botY,
                             cap, DSTRIP_SKIN_BOTT,
                             DrawStripSkinResFor(fam, "bot_l"));
   dirty |= DrawStripSkinBmp(DrawStripSkinPiece(fam, 7), sx + cap, botY,
                             midW, DSTRIP_SKIN_BOTT, DrawStripSkinResFor(fam, "bot_m"));
   dirty |= DrawStripSkinBmp(DrawStripSkinPiece(fam, 8), sx + TW - cap, botY,
                             cap, DSTRIP_SKIN_BOTT,
                             DrawStripSkinResFor(fam, "bot_r"));
   //--- P-PAL-17b (2026-10-02) — THE PLATE'S OWN NINE, AS THE TERMINATOR HOLDS IT.
   //--- The MEASURED report: the board's content ends where HEX ends (BH=556, the
   //--- flushed witness agrees) and the CARD carries ~75px more below it. The plate
   //--- is nine OBJ_BITMAP_LABELs and the model above says where each one lands — so
   //--- either the model is wrong or the objects are, and only the OBJECTS can say.
   //--- ONE line, once per open, through the flushed channel, naming every piece's
   //--- own x/y/size and the bmp the terminal resolved: XSIZE/YSIZE only CROP, so a
   //--- piece whose canvas is taller than its size shows more rows than the painter
   //--- believes, and nothing on the chart can say so but this read.
   if(fam == 2)
   {
      static bool said = false;
      if(!said)
      {
         said = true;
         string s = "[drawstrip] PLATE fam=2 rect=" + IntegerToString(x) + "," + IntegerToString(y)
                    + "," + IntegerToString(w) + "x" + IntegerToString(h)
                    + " midH=" + IntegerToString(midH) + " botY=" + IntegerToString(botY)
                    + " cap=" + IntegerToString(cap);
         for(int i = 0; i < 9; i++)
         {
            string pn = DrawStripSkinPiece(fam, i);
            s += " | " + pn + "=";
            if(ObjectFind(0, pn) < 0) s += "GONE";
            else s += IntegerToString(ObjectGetInteger(0, pn, OBJPROP_XDISTANCE)) + ","
                    + IntegerToString(ObjectGetInteger(0, pn, OBJPROP_YDISTANCE)) + ","
                    + IntegerToString(ObjectGetInteger(0, pn, OBJPROP_XSIZE)) + "x"
                    + IntegerToString(ObjectGetInteger(0, pn, OBJPROP_YSIZE))
                    + ",z" + IntegerToString(ObjectGetInteger(0, pn, OBJPROP_ZORDER));
         }
         DrawStripDiagEmit(s);
      }
   }
   //--- P-DRAW-35 (2026-09-25): OBJ_BITMAP_LABEL does NOT honour alpha on a white
   //--- chart — every transparent pixel in the skin BMP reads as white.  A solid
   //--- RECTANGLE_LABEL behind the skin (same content rect, no border, Z_STRIP-1)
   //--- fills the rounded-corner gap and the shadow margin so the panel looks
   //--- identical on white and black charts.  This replaces the old "delete bg when
   //--- skin fits" path; the bg rect is now the permanent underlayer.
   //--- P-DRAW-48: fam 2 (the board) has its OWN underlayer; the strip's
   //--- `PnlDrawS_BG` was reused by the first cut and moved the strip's own
   //--- floor under the board — one surface, one name.
   string bg = (fam == 1 ? DrawStripGearBgName()
                         : (fam == 2 ? DrawStripBoardBgName() : DrawStripBgName()));
   if(ObjectFind(0, bg) < 0)
   {
      if(!ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return dirty;
      ObjectSetInteger(0, bg, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg, OBJPROP_COLOR,       fill);
      ObjectSetInteger(0, bg, OBJPROP_BACK,        false);
      ObjectSetInteger(0, bg, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(0, bg, OBJPROP_HIDDEN,      true);
      ObjectSetInteger(0, bg, OBJPROP_ZORDER,      Z_STRIP_BG);
      dirty = true;
   }
   //--- P-DRAW-122 (2026-10-01): THE UNDERLAYER'S RUNG IS RE-ASSERTED EVERY PAINT.
   //--- This is the one object every OTHER pixel of the strip is drawn over, so a
   //--- stale rung here is the whole surface: after a reattach the skin pieces are
   //--- born again at their own z while this rect keeps an older one, and the plate
   //--- swallows them. Compare-guarded; a still frame writes nothing.
   dirty |= DrawStripSetInt(bg, OBJPROP_ZORDER,      Z_STRIP_BG);
   dirty |= DrawStripSetInt(bg, OBJPROP_BACK,        false);
   dirty |= DrawStripSetInt(bg, OBJPROP_XDISTANCE, x);
   dirty |= DrawStripSetInt(bg, OBJPROP_YDISTANCE, y);
   dirty |= DrawStripSetInt(bg, OBJPROP_XSIZE,     w);
   dirty |= DrawStripSetInt(bg, OBJPROP_YSIZE,     h);
   dirty |= DrawStripSetInt(bg, OBJPROP_COLOR,     fill);
   dirty |= DrawStripSetInt(bg, OBJPROP_BGCOLOR,   fill);
   return dirty;
}
//--- the strip's own plate: the caller's rect is the strip's own content box.
bool DrawStripSkinPaint()
{
   return DrawStripSkinPaintAt(0, s_dsX, s_dsY, s_dsW, s_dsH,
                               DSTRIP_STRIP_GRID_TOP, -1, DSTRIP_STRIP_BODY_TOP);
}
//--- P-DRAW-32: the SETTINGS PANEL's plate, at ITS OWN origin and size.
//--- P-DRAW-35: DrawStripSkinPaintAt(1,...) now owns DrawStripGearBgName() — both the
//--- skin-fits underlayer and the fallback flat rect — so there is no duplication here.
//--- P-DRAW-40 (2026-09-25): the drawing's own pixel box, measured the way P-DRAW-20
//--- measures it (every anchor that projects; the anchors are the contiguous 0..n-1
//--- set). ONE implementation, because a second copy of a measurement is how two
//--- surfaces come to disagree about where the work is (H-06). P-DRAW-73: it sits
//--- ABOVE the board's placer too, which now asks the same question (H-05).
bool DrawStripDrawingBox(const string name, int &x1, int &y1, int &x2, int &y2)
{
   bool have = false;
   for(int i = 0; i < 3; i++)
   {
      int ax = 0, ay = 0;
      if(!DrawAnchorXY(name, i, ax, ay)) break;   // anchors are contiguous 0..n-1
      if(!have) { x1 = ax; x2 = ax; y1 = ay; y2 = ay; have = true; continue; }
      if(ax < x1) x1 = ax;
      if(ax > x2) x2 = ax;
      if(ay < y1) y1 = ay;
      if(ay > y2) y2 = ay;
   }
   return have;
}
//--- P-DRAW-45 (2026-09-25) — THE OVERLAP, IN PIXELS. One owner for both placers: the
//--- panel's eight scored positions and the board's docked spot, so two surfaces can
//--- never answer "do we touch?" two different ways (H-06).
int DrawStripRectOverlap(const int ax, const int ay, const int aw, const int ah,
                         const int bx, const int by, const int bw, const int bh)
{
   int x1 = MathMax(ax, bx), y1 = MathMax(ay, by);
   int x2 = MathMin(ax + aw, bx + bw), y2 = MathMin(ay + ah, by + bh);
   if(x2 <= x1 || y2 <= y1) return 0;
   long w = (long)x2 - (long)x1, h = (long)y2 - (long)y1;
   long a = w * h;
   if(a > 2147483647) return 2147483647;
   return (int)a;
}


//--- P-DRAW-48 — THE OPACITY BAR'S OWN GEOMETRY AND ITS OWN GRAB. The paint and
//--- the hand read ONE answer: the label keeps the RECENT column, the readout its
//--- own seat, and the bar is what is left between them (the cards' track metrics).
int DrawStripHexX() { return s_dsBX + DSTRIP_PAD + DSTRIP_PREC_LW; }
//--- P-DRAW-66: the track starts after the FIELD now (the band is shared), so the
//--- hand's drag begins on the bar and a press on the field can never move it.
int DrawStripOpTrackX() { return DrawStripHexX() + DSTRIP_HEX_W + DSTRIP_PAD; }
int DrawStripOpTrackW()
{
   int w = s_dsBW - DSTRIP_PAD - (DrawStripOpTrackX() - s_dsBX) - DSTRIP_OP_VW;
   return (w > 2 * DSTRIP_KNOB_W) ? w : 2 * DSTRIP_KNOB_W;
}
//--- the value a pointer x means, over the SAME span the knob rides — the exact
//--- inverse of the knob's own position, so what the hand sees is what `NN%` says.
int DrawStripOpValueAt(const int mx)
{
   int span = DrawStripOpTrackW() - DSTRIP_KNOB_W;
   if(span <= 0) return DRAW_OP_MIN;
   double f = (mx - DrawStripOpTrackX()) / (double)span;
   if(f < 0.0) f = 0.0;
   if(f > 1.0) f = 1.0;
   int v = (int)MathRound(f * 100.0);
   if(v < DRAW_OP_MIN) v = DRAW_OP_MIN;
   if(v > 100) v = 100;
   return v;
}
//--- P-DRAW-75 (2026-09-28) — THE PLATE IS A DERIVED HEIGHT, SO IT IS ALSO A
//--- DERIVED RECT. Everything family 1 paints sits inside `s_dsGearW0 x s_dsGearH`,
//--- but a band left by a TALLER layout, or by a path that resized the plate without
//--- re-running the body walk, keeps its own object and its own Y — the reported tower
//--- of empty 42px bands under the panel, with no content owning them. One bounded
//--- sweep on a REAL layout change (never per paint) takes any band or seam whose own
//--- rect the plate no longer contains. `DrawStripBodyPaint` owns the bands this
//--- surface SHOULD have; this owns the ones it must not keep.
bool DrawStripGearTrimOverflow()
{
   bool dirty = false;
   for(int b = 0; b < DSTRIP_BODY_MAX; b++)
   {
      string nm = DrawStripBodyName(1, b);
      if(ObjectFind(0, nm) >= 0)
      {
         int by = (int)ObjectGetInteger(0, nm, OBJPROP_YDISTANCE);
         int bh = (int)ObjectGetInteger(0, nm, OBJPROP_YSIZE);
         int bw = (int)ObjectGetInteger(0, nm, OBJPROP_XSIZE);
         //--- the band's OWN bottom, not a 42px worst case: the last band is a
         //--- short tail, so `by + 42` killed a band the plate still holds and left
         //--- the ones a TALLER tab had put below the plate standing on the chart.
         if(by < s_dsGEY || by + bh > s_dsGEY + s_dsGearH || bw > s_dsGearW0)
         { ObjectDelete(0, nm); dirty = true; }
      }
      string sn = DrawStripSeamName(1, b);
      if(ObjectFind(0, sn) >= 0)
      {
         int sy = (int)ObjectGetInteger(0, sn, OBJPROP_YDISTANCE);
         if(sy < s_dsGEY || sy > s_dsGEY + s_dsGearH)
         { ObjectDelete(0, sn); dirty = true; }
      }
   }
   return dirty;
}
bool DrawStripGearPlate()
{
   bool dirty = false;
   // P-DRAW-xx: the gear panel wears the CARDS' own pnl_cardW* skin — the same
   // composed body BiotakPanels uses for wide cards (top cap + one mid per pair-line
   // + bot cap), so the panel reads as a card and the strip is the only ds_* surface.
   // Height = DSTRIP_GEAR_HEAD_H + (1+rows)*DSTRIP_GEAR_ROW_H + DSTRIP_GEAR_FOOT_H.
   // Card geometry mirrors BiotakPanels.mqh (included AFTER this file, so names
   // are unavailable here): margin=14 HEAD_H=56 FOOT_H=48 ROW_H=42.
   int gx = s_dsGEX, gy = s_dsGEY, gw = s_dsGearW0, gh = s_dsGearH;
   //--- P-DRAW-83 (2026-09-29) — THE PLATE IS THE BOTTOM OF ITS OWN LADDER, ALWAYS.
   //--- These four writers passed `Z_PANEL_CARD` (1480) while every control on this
   //--- panel is painted by `DrawStripBtn`/`DrawStripFace` — the STRIP's rungs,
   //--- Z_STRIP_ICON 1441 and Z_STRIP_OVER 1442. 1480 > 1441, so the plate's own card
   //--- bake (one opaque bitmap, the whole 340x348 of it) sat ABOVE the tabs, the
   //--- hex fields, the Interior switch and the foot: paint order hid them, and click
   //--- order gave every pixel of the panel to an object no branch of the click
   //--- router owns. The panel answered NOTHING. The cards' own ladder survives that
   //--- arrangement only because `PnlSkinButtonAct` hit-tests their controls back by
   //--- rectangle on the press (P-UI-128); this panel has no such second channel, so
   //--- the plate must not be above its controls at all. Z_STRIP is the rung the
   //--- strip's own plate wears (DrawStripSkinPaintAt, family 0) and the rung
   //--- `DrawStripSkinBmp` defaults to — one value, both plates.
   //--- P-DRAW-78: EXACT card rows. Content = head 56 + T rows + foot 42 + air 6;
   //--- the cards' own plate for that height is `pnl_card{T-1}` (56 + n*42 + 48):
   //--- the foot row plus the 6px air fills the card's 48px footer exactly, and
   //--- every content row lands on a card row. The old air (34) put every height
   //--- 28px off every bake, which is why the composed body never reached the
   //--- plate's bottom edge.
   //--- LITERALS, not PNL_*: BiotakPanels.mqh is included AFTER this file, so its
   //--- constants do not exist here. 104 = 56+48 · 42 = the row · 70 = 14+56 ·
   //--- 62 = 48+14.
   int cardN = (gh - 104) / 42;
   bool cardExact = ((gh - 104) % 42 == 0 && cardN >= 1 && cardN <= 10);
   bool narrow = (gw == DSTRIP_GEAR_W);
   //--- P-LOG-10 (2026-10-01) — THE PLATE MUST BE YOUNGER THAN NOTHING. MT4 paints
   //--- in creation order; OBJPROP_ZORDER rules CLICKS alone (P-DRAW-83 already met
   //--- this: «paint order hid them, and click order gave every pixel»). MEASURED
   //--- 23:48 frame + the user's own screen: the x button MOVED narrow->wide
   //--- (1178->1490), the census reads it sane at the wide seat, and it still shows
   //--- nothing — a write never raises a painted object. The wide tiles are CREATED
   //--- (re-created for every new pairN) after the content of earlier paints, so
   //--- everything born before them — the left column, the head, the x — paints
   //--- under the card while every click still lands (z 1441/1442 > 1440). The only
   //--- raise MT4 honours is CREATE: when the plate is about to (re)appear while
   //--- family content predates it, purge the family once — the tiles land first,
   //--- the DrawStripGearPaint() that follows in the same paint recreates every
   //--- control above them, and the order stays correct until the plate reshapes.
   static int s_dsPlatePairN = -1;   // -1 = the last paint was the bake (or the panel was shut)

   //--- P-DRAW-78: THE SQUARE UNDERLAYER IS THE SECOND BOX. The cards bake their
   //--- own radius, border and shadow into `pnl_card*` and carry NO rect behind
   //--- them; this rect filled the transparent corners of the rounded skin with a
   //--- hard square, which is the report: two boxes, mixed, the inner one with no
   //--- radius. It is deleted here, every paint, so it cannot survive an upgrade.
   if(ObjectFind(0, DrawStripGearBgName()) >= 0)
   { ObjectDelete(0, DrawStripGearBgName()); dirty = true; }

   if(narrow && cardExact)
   {
      //--- P-LOG-10: returning from a wide phase, the content was recreated ABOVE
      //   where a fresh bake would land — purge once so the bake is born first.
      if(s_dsPlatePairN >= 0 && ObjectFind(0, "PnlDrawS_Gbake") < 0)
         dirty |= DrawStripGearObjectsPurge();
      s_dsPlatePairN = -1;
      //--- ONE baked card, both corners rounded, zero composition. The bake
      //--- carries the 14px margin itself (cardW+28 x ph+28, PnlCreate's seats).
      dirty |= DrawStripSkinBmp("PnlDrawS_Gbake", gx - 14, gy - 14, gw + 28, gh + 28,
                                "::Files\\Icons\\pnl_card" + IntegerToString(cardN) + ".bmp",
                                Z_STRIP);
      //--- a tab that was wide keeps its composed tiles: they die here.
      if(ObjectFind(0, "PnlDrawS_Gtop") >= 0)
      { ObjectDelete(0, "PnlDrawS_Gtop"); dirty = true; }
      if(ObjectFind(0, "PnlDrawS_Gbot") >= 0)
      { ObjectDelete(0, "PnlDrawS_Gbot"); dirty = true; }
      for(int lm = 0; lm < DSTRIP_GEAR_BLK_MAX; lm++)
      {
         string lmn = "PnlDrawS_Gmid" + IntegerToString(lm);
         if(ObjectFind(0, lmn) >= 0) { ObjectDelete(0, lmn); dirty = true; }
      }
   }
   else
   {
      //--- WIDE (or the off-grid net, which by construction cannot happen): the
      //--- composed W body. pairN counts the same rows the bake above would, so
      //--- the caps land on the same edges either way.
      int pairN = cardExact ? cardN : (gh - 104 + 41) / 42;
      if(pairN < 1) pairN = 1;
      if(pairN > DSTRIP_GEAR_BLK_MAX) { DrawStripSkinPurgeAt(1); return false; }
      //--- P-LOG-10: entering the composed branch, or a body that changed height —
      //   any tile born now would cover every control born before it. Purge once;
      //   the tiles land first and GearPaint recreates the whole content above.
      if(s_dsPlatePairN != pairN)
         dirty |= DrawStripGearObjectsPurge();
      //--- P-DRAW-110 (2026-10-01) — THE BODY STARTS AT THE HEAD'S OWN EDGE.
      //--- The three W bakes are drawn from the SAME origin the bake above uses,
      //--- `gy - 14` (the plate's own 14px margin), and the top cap is `14 + 70`:
      //--- its own 14px pad is spent ABOVE the head, so the head band ends at
      //--- `gy + DSTRIP_GEAR_HEAD_H` (56) and the body must continue THERE. This
      //--- block started it at `gy + 70` — the cap's HEIGHT, not its edge — so on
      //--- every WIDE tab (Style, Row: the only two that compose instead of baking)
      //--- the whole body sat **14px low**: a 14px transparent band under the header
      //--- (`gy+56 .. gy+70`, where the tab track's bed was the only thing covering
      //--- it) and the bottom cap ending at `gy + gh + 28` instead of `gy + gh + 14`.
      //--- The owner is the cards' own composition (BiotakPanels_Build.mqh:727-737:
      //--- mids at `py + PNL_HEAD_H + li*PNL_ROW_H`, foot cap at `+ pairN*PNL_ROW_H`)
      //--- and this is the same law on the strip's origin: MEASURED, `pnl_cardWtop`
      //--- 652x70 with its opaque rows at y10..69, `pnl_cardWmid` 652x42 with y0..41
      //--- — so `56 + 42*pairN + 62` = `gh + 14`, the plate's own bottom.
      // top cap — pnl_cardWtop.bmp (14+56=70px)
      dirty |= DrawStripSkinBmp("PnlDrawS_Gtop",
                                gx - 14, gy - 14, gw + 28, 70,
                                "::Files\\Icons\\pnl_cardWtop.bmp", Z_STRIP);
      for(int li = 0; li < DSTRIP_GEAR_BLK_MAX; li++)
      {
         string mn = "PnlDrawS_Gmid" + IntegerToString(li);
         if(li < pairN)
            dirty |= DrawStripSkinBmp(mn, gx - 14, gy + DSTRIP_GEAR_HEAD_H + li * 42,
                                      gw + 28, 42, "::Files\\Icons\\pnl_cardWmid.bmp",
                                      Z_STRIP);
         else if(ObjectFind(0, mn) >= 0) { ObjectDelete(0, mn); dirty = true; }
      }
      // bot cap — pnl_cardWbot.bmp (48+14=62px)
      dirty |= DrawStripSkinBmp("PnlDrawS_Gbot",
                                gx - 14, gy + DSTRIP_GEAR_HEAD_H + pairN * 42, gw + 28, 62,
                                "::Files\\Icons\\pnl_cardWbot.bmp", Z_STRIP);
      if(ObjectFind(0, "PnlDrawS_Gbake") >= 0)
      { ObjectDelete(0, "PnlDrawS_Gbake"); dirty = true; }
      s_dsPlatePairN = pairN;   // P-LOG-10: this body's tiles are now the family's elders
   }
   //--- the retired `ds_*` nine-slice for this family goes with it, every paint.
   for(int op = 0; op <= 8; op++)
   {
      string on = DrawStripGearSkinName(op);
      if(ObjectFind(0, on) >= 0) { ObjectDelete(0, on); dirty = true; }
   }
   //--- P-DRAW-79: THE `Gcard*` SPELLING IS THE ORPHAN, AND IT IS NOT A THEORETICAL
   //--- ONE. `PnlDrawS_Gcard*` also matches the family purge's own
   //--- `PnlDrawS_GB*` test only by accident of the letter, but worse: a chart
   //--- painted by the build that introduced it carries those five objects, and
   //--- the `DrawStripSkinBmp` of THIS build never re-writes nor deletes them —
   //--- so a card-sized plate from the old build sits under the new one, at a
   //--- stale x/y, until the user's next full sweep. The rename ships with the
   //--- sweep that removes the old spelling. Bounded: five exact names, once per
   //--- paint, and a delete only when the object is really there.
   if(ObjectFind(0, "PnlDrawS_Gcard") >= 0)
   { ObjectDelete(0, "PnlDrawS_Gcard"); dirty = true; }
   if(ObjectFind(0, "PnlDrawS_GcardT") >= 0)
   { ObjectDelete(0, "PnlDrawS_GcardT"); dirty = true; }
   if(ObjectFind(0, "PnlDrawS_GcardB") >= 0)
   { ObjectDelete(0, "PnlDrawS_GcardB"); dirty = true; }
   for(int oc = 0; oc < DSTRIP_GEAR_BLK_MAX; oc++)
   {
      string ocn = "PnlDrawS_GcardM" + IntegerToString(oc);
      if(ObjectFind(0, ocn) >= 0) { ObjectDelete(0, ocn); dirty = true; }
   }
   // purge body/seam rects (DrawStripBodyPaint no longer used for fam=1)
   dirty |= DrawStripBodyPurge(1);

   //--- log once per real height change
   static int s_dsPlateTab = -1, s_dsPlateH = -1;
    if(s_dsGear != s_dsPlateTab || gh != s_dsPlateH)
    {
       s_dsPlateTab = s_dsGear; s_dsPlateH = gh;
       dirty |= DrawStripGearTrimOverflow();
       //--- P-DRAFT-02: THE PLATE'S OWN VERDICT, IN ONE LINE. Every earlier report
       //--- of "the panel has no skin" was answered by an argument about which
       //--- branch SHOULD run; this line reports which one DID, whether the object
       //--- exists, what the terminal actually stored for its file, and the
       //--- transparency index that silently replaces the card tone with the
       //--- chart's background. One line, and the next screenshot carries the
       //--- answer with it.
       string plateName = (narrow && cardExact) ? "PnlDrawS_Gbake" : "PnlDrawS_Gtop";
       string wantRes   = (narrow && cardExact)
                          ? ("::Files\\Icons\\pnl_card" + IntegerToString(cardN) + ".bmp")
                          : "::Files\\Icons\\pnl_cardWtop.bmp";
       Print("[drawstrip] PLATE tab=", s_dsGear, " h=", gh, " w=", gw,
             " cardN=", cardN, " exact=", (cardExact ? 1 : 0), " narrow=", (narrow ? 1 : 0),
             " -> branch=", (narrow && cardExact ? "bake" : "wide"),
             " obj=", plateName,
             " exists=", (ObjectFind(0, plateName) >= 0 ? 1 : 0),
             " want=", wantRes,
             " got=", (ObjectFind(0, plateName) >= 0
                       ? ObjectGetString(0, plateName, OBJPROP_BMPFILE, 0) : "-"),
             " xy=", gx, ",", gy,
             " z=", (ObjectFind(0, plateName) >= 0
                     ? (int)ObjectGetInteger(0, plateName, OBJPROP_ZORDER) : -1),
             " plateFill=", (int)DrawStripPlateFill(),
             " rows=", s_dsGRN, " grids=", s_dsGGN, " secs=", s_dsGearSecN);
    }
    return dirty;
}

//--- P-DRAW-32 (2026-09-24) — WHERE THE SETTINGS PANEL OPENS. User order: «پنل
//--- تنظیمات از استریپ جدا باشه». The panel is its own card, so it needs its own spot
//--- and the project's two placement laws apply unchanged (P-BK-27: a toolbar never
//--- covers the handle it belongs to; P-DRAW-31: no two surfaces on one pixel). The
//--- hand's own carry (`s_dsGearManual`) wins everything and is only clamped — a panel
//--- the user placed is not moved by a repaint.
//--- P-DRAW-45 (2026-09-25) — EIGHT POSITIONS, SCORED, ON THE FINAL HEIGHT. User
//--- order: «حتما نباید به سمت پایین باز بشه، باید هوشمند باز بشه سمت راست بالا...
//--- بهترین برای همه سناریو ممکن ... هر دفهه باید کاربر بگیره درگ بکنه». The old
//--- ladder was four sides in a FIXED order and, when none fitted whole, it clamped
//--- candidate 0 — hanging the panel off the bottom edge until the user dragged it
//--- every time. Now four sides AND four corners are measured against the panel's
//--- FINAL height (the layout pass before this paint owns `s_dsGearH`), scored by
//--- what they cover and by the window they leave; the least-bad wins, not the first.
#define DSTRIP_GEAR_POS_N 8
string DrawStripGearSideName(const int i)
{
   string n[DSTRIP_GEAR_POS_N] = {"below", "above", "right", "left",
                                  "below-right", "above-right", "right-low", "left-low"};
   if(i < 0 || i >= DSTRIP_GEAR_POS_N) return "?";
   return n[i];
}

void DrawStripPlaceGear()
{
   if(s_dsGear == 0 || s_dsGearW0 <= 0 || s_dsGearH <= 0) return;
   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0); if(cw <= 0) cw = 1920;
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0); if(ch <= 0) ch = 1080;
   int gm = 4 + DSTRIP_SKIN_M;   // P-DRAW-29: the skin stands past the content
   int maxX = cw - s_dsGearW0 - gm, maxY = ch - s_dsGearH - gm;
   if(maxX < gm) maxX = gm;
   if(maxY < gm) maxY = gm;
   if(s_dsGearManual || (s_dsGearPlaced && s_dsGearPlacedObj == s_dsObj))
   {
      //--- P-DRAW-88: the hand's spot — or the last scored one — is kept. A tab
      //--- switch changes the HEIGHT, never the home: clamp to the window so a
      //--- taller tab cannot hang off the edge, but never re-score to a corner.
      if(s_dsGEX < gm) s_dsGEX = gm;
      if(s_dsGEY < gm) s_dsGEY = gm;
      if(s_dsGEX > maxX) s_dsGEX = maxX;
      if(s_dsGEY > maxY) s_dsGEY = maxY;
      return;
   }
   //--- P-DRAW-40 (2026-09-25): THE DRAWING IS A HARD RULE FOR THE PANEL TOO.
   //--- Reported: «پنل روی خوده ابجکت ظاهر میشه» — the placer knew the plate and
   //--- the open card and nothing about the object this strip serves (B-10: a
   //--- surface never covers the drawing it belongs to; P-DRAW-31's one-rule-two-
   //--- rects law). Same owner the fresh strip asks: `DrawStripDrawingBox`.
   int dx1 = 0, dy1 = 0, dx2 = 0, dy2 = 0;
   bool haveDraw = DrawStripDrawingBox(s_dsObj, dx1, dy1, dx2, dy2);
   const int W = s_dsGearW0, H = s_dsGearH;
   int px[DSTRIP_GEAR_POS_N], py[DSTRIP_GEAR_POS_N];
   px[0] = s_dsX;                    py[0] = s_dsY + s_dsH + DSTRIP_GEAR_GAP;   // below
   px[1] = s_dsX;                    py[1] = s_dsY - H - DSTRIP_GEAR_GAP;       // above
   px[2] = s_dsX + s_dsW + DSTRIP_GEAR_GAP; py[2] = s_dsY;                    // right
   px[3] = s_dsX - W - DSTRIP_GEAR_GAP;     py[3] = s_dsY;                    // left
   px[4] = s_dsX + s_dsW - W;        py[4] = s_dsY + s_dsH + DSTRIP_GEAR_GAP;   // below-right
   px[5] = s_dsX + s_dsW - W;        py[5] = s_dsY - H - DSTRIP_GEAR_GAP;       // above-right
   px[6] = s_dsX + s_dsW + DSTRIP_GEAR_GAP; py[6] = s_dsY + s_dsH - H;         // right, low
   px[7] = s_dsX - W - DSTRIP_GEAR_GAP;     py[7] = s_dsY + s_dsH - H;         // left, low
   const bool cardOpen = (g_UIPanelRX >= 0 && g_UIPanelRW > 0 && g_UIPanelRH > 0);
   //--- P-DRAW-73 (2026-09-28): the COLOUR BOARD is a surface too, and the panel's
   //--- score did not know it — so the panel could be placed straight through an open
   //--- board (H-05's other half; the board's placer now answers the same question).
   const bool boardOpen = (DrawStripIsColorSlot(s_dsPicker) && s_dsBW > 0 && s_dsBH > 0);
   int best = -1, bestAir = 0; long bestScore = 0;
   for(int c = 0; c < DSTRIP_GEAR_POS_N; c++)
   {
      if(px[c] < gm || py[c] < gm || px[c] > maxX || py[c] > maxY) continue;   // off the window
      const int oDraw  = haveDraw ? DrawStripRectOverlap(px[c], py[c], W, H, dx1, dy1, dx2 - dx1, dy2 - dy1) : 0;
      const int oPlate = DrawStripRectOverlap(px[c], py[c], W, H, s_dsX, s_dsY, s_dsW, s_dsH);
      const int oCard  = cardOpen ? DrawStripRectOverlap(px[c], py[c], W, H, g_UIPanelRX, g_UIPanelRY, g_UIPanelRW, g_UIPanelRH) : 0;
      const int oBoard = boardOpen ? DrawStripRectOverlap(px[c], py[c], W, H, s_dsBX, s_dsBY, s_dsBW, s_dsBH) : 0;
      // P-DRAW-45: the WORK is punished an order of magnitude above the surfaces it
      // shares the screen with (B-10: the panel never covers the drawing it serves),
      // the plate next (P-DRAW-31: two surfaces never share a pixel) and the open card
      // last; between two spots that cover nothing, the one leaving more window wins,
      // and a real tie keeps the reading order (below, above, right, left, corners).
      const long score = -((long)oDraw * 1000 + (long)oPlate * 20 + (long)oBoard * 20 + (long)oCard * 5);
      const int air = MathMin(MathMin(px[c] - gm, py[c] - gm),
                              MathMin(maxX - px[c], maxY - py[c]));
      if(best < 0 || score > bestScore || (score == bestScore && air > bestAir))
      { best = c; bestScore = score; bestAir = air; }
   }
   if(best < 0) best = 0;   // nothing fits whole: the reading order, clamped below
   s_dsGEX = px[best]; s_dsGEY = py[best];
   s_dsGearPlaced = true; s_dsGearPlacedObj = s_dsObj;   // P-DRAW-88: scored once
   if(s_dsGEX < gm) s_dsGEX = gm;
   if(s_dsGEY < gm) s_dsGEY = gm;
   if(s_dsGEX > maxX) s_dsGEX = maxX;
   if(s_dsGEY > maxY) s_dsGEY = maxY;
   //--- P-DRAW-45: ONE line per REAL move — a paint may run many times a second while
   //--- the pointer moves and this project bans unbounded logging. It names the side,
   //--- the spot, the panel size, the window and the air the winner left.
   static int  s_gpLogX = -1, s_gpLogY = -1, s_gpLogSide = -9;
   if(s_gpLogSide != best || s_gpLogX != s_dsGEX || s_gpLogY != s_dsGEY)
   {
      s_gpLogSide = best;
      s_gpLogX = s_dsGEX; s_gpLogY = s_dsGEY;
      Print("[drawstrip] gear side=", DrawStripGearSideName(best),
            " pos=(", s_dsGEX, ",", s_dsGEY, ") size=", W, "x", H,
            " chart=", cw, "x", ch, " air=", bestAir);
   }
}

//--- P-DRAW-42 (2026-09-25) — NO ORPHAN SURVIVES A REATTACH. `PnlDrawS_*` carries no
//--- chart id (one instance per chart), so a plate family or a flat bg rect left by
//--- a killed terminal is still on the chart at the next attach while every static
//--- here starts clean — the user's dark rectangle with nothing on it. One sweep,
//--- once per session, at the first paint: before this session made anything, and
//--- all of one ObjectsDeleteAll call (the same orphan purge InitializeUIStates does
//--- for its own prefix). Costs nothing after the first paint.
static bool s_dsSwept = false;
//--- P-DRAW-84: the gear panel's press already found its control. A release then
//--- arrives on BOTH channels (CHARTEVENT_CLICK and CHARTEVENT_OBJECT_CLICK), and
//--- the dismissal branch below reads a press that lands on the panel as a click on
//--- the chart — which would shut the panel the user is working in. One flag, set by
//--- the press edge and read by the release, so one gesture is one owner.
static bool s_dsGearPressSpent = false;
void DrawStripOrphanSweep()
{
   if(s_dsSwept) return;
   s_dsSwept = true;
   ObjectsDeleteAll(0, "PnlDrawS_");
}
#endif // DRAW_STRIP_SKIN_MQH
// DrawStrip_Paint.mqh - DrawStrip split 2026-09-29: exact lines 5339-6238 of DrawStrip.mqh, byte-identical, zero renames.
#ifndef DRAW_STRIP_PAINT_MQH
#define DRAW_STRIP_PAINT_MQH


//--- ONE painter, called on open and after every tap: reads the held object and
//--- writes only what changed (the guarded-write law of this codebase), and asks
//--- for a repaint only when something really moved (P-DRAW-09d).
void DrawStripPaint()
{
   if(s_dsDiagAfter == 1) DrawStripDiagAfterRun();   // P-LOG-8: the next pass re-walks the dump's own name list
   //--- P-DRAW-120 (2026-10-01): this line was BELOW the gate, so P-DRAW-42's own
   //--- promise ("NO ORPHAN SURVIVES A REATTACH ... one sweep, once per session, at
   //--- the first paint") only held for a session whose FIRST paint happened with the
   //--- strip open — the one case that never needs it. A chart reloaded with nothing
   //--- open (every byte of this unit's state resets while `PnlDrawS_*` stays) painted
   //--- nothing, swept nothing, and left the previous instance's family on screen as
   //--- the half-drawn panel of the 2026-10-01 report. The sweep is one flag read after
   //--- the first call and belongs to the paint that runs at all, closed or open.
   DrawStripOrphanSweep();
   if(!s_dsOpen || s_dsObj == "") return;
   if(s_dsKind == DK_NONE || ObjectFind(0, s_dsObj) < 0)
   { Print("[drawstrip] close: paint found no object obj=\"", s_dsObj, "\" kind=", (int)s_dsKind); DrawStripClose(); return; }
   // P-DRAW-08c: the strip is the indicator's surface, so the indicator's own
   // hide-all (the F key) hides it too — a toolbar left floating over a chart the
   // user just muted is the same complaint as a label that stays lit.
   if(IsIndicatorHidden()) { Print("[drawstrip] close: indicator hidden (F) obj=\"", s_dsObj, "\""); DrawStripClose(); return; }
   // P-DRAW-08f: and a drawing the user put away ON THIS TIMEFRAME (the terminal's
   // own "hide on this period", which is OBJPROP_TIMEFRAMES) must not leave a
   // toolbar floating over nothing — the strip serves what is on screen.
   if((long)ObjectGetInteger(0, s_dsObj, OBJPROP_TIMEFRAMES) == OBJ_NO_PERIODS)
   { Print("[drawstrip] close: drawing masked off this timeframe obj=\"", s_dsObj, "\""); DrawStripClose(); return; }
   s_dsN = DrawStripQuickCount(s_dsKind);
   bool dirty = false;

   //--- P-LOG-10 (2026-10-02): THE REBIRTH ANSWER. A 9-slice plate the !fits purge
   //--- took down while its content lived is answered HERE — at the very top of the
   //--- next pass, before ANY painter runs — with one purge of the whole UI family.
   //--- Every painter below re-creates what it owns from the state it already holds,
   //--- plate-first, so nothing can be born over content again.
   if(s_dsSkinPlateDied)
   {
      s_dsSkinPlateDied = false;
      ObjectsDeleteAll(0, "PnlDrawS_", -1, -1);
   }

   //--- the plate: the cards' own skin when it fits (P-DRAW-29), the legacy
   //--- flat rect when the layout cannot be skinned — created once, guarded
   //--- after (X, Y, W, H all drift).
   dirty |= DrawStripSkinPaint();
   string bg = DrawStripBgName();
   if(!DrawStripSkinFits())
   {
      if(ObjectFind(0, bg) < 0)
      {
         //--- P-DRAW-101 (2026-09-30) — A PLATE THAT WILL NOT BUILD IS NOT A REASON
         //--- TO BUILD NOTHING. This was `if(!ObjectCreate(...)) return;`, and the
         //--- `return` is the whole painter: one refused object name (the terminal's
         //--- own object budget, a name already taken by a chart that died dirty)
         //--- took the grip, the badge, the quick cells, the actions, the colour
         //--- board, its RECENT band, the HEX field, the opacity bar, the popover,
         //--- AND the two calls at the bottom that place, plate and paint the gear
         //--- panel — with `dirty` never reaching ChartRedraw, so the frame before it
         //--- stayed frozen. Three surfaces to nothing, over one rectangle label.
         //--- The plate is the one piece that may be missing; everything after it
         //--- degrades to the previous look, which is what the guarded writes below
         //--- already are (a write aimed at a name the chart does not carry answers
         //--- nothing and costs one read).
         if(ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         {
            ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, DrawStripPlateFill());

            ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
            ObjectSetInteger(0, bg, OBJPROP_COLOR, DSTRIP_CLR_LINE);
            ObjectSetInteger(0, bg, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, bg, OBJPROP_BACK, false);
            ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, bg, OBJPROP_ZORDER, Z_STRIP);
            dirty = true;
         }
      }
      //--- P-DRAW-122 (2026-10-01): the flat plate's rung and back flag are re-asserted
      //--- every paint, beside the geometry above. The rect is created once and guarded
      //--- after, so a plate that survives a reattach kept the rung of the OLD instance
      //--- while every painter on top was born again — the strip's own body under its
      //--- own plate. Compare-guarded; a still frame writes nothing.
      dirty |= DrawStripSetInt(bg, OBJPROP_ZORDER, Z_STRIP);
      dirty |= DrawStripSetInt(bg, OBJPROP_BACK, false);
      dirty |= DrawStripSetInt(bg, OBJPROP_XDISTANCE, s_dsX);
      dirty |= DrawStripSetInt(bg, OBJPROP_YDISTANCE, s_dsY);
      dirty |= DrawStripSetInt(bg, OBJPROP_XSIZE, s_dsW);
      dirty |= DrawStripSetInt(bg, OBJPROP_YSIZE, s_dsH);
   }

   int rowY = s_dsY + DSTRIP_PAD;
   //--- grip (drag) + badge (kind xN, info only).
   string hg = DrawStripGripName();
   string tipGrip = "Drag to move the strip";
   dirty |= DrawStripBtn(hg, s_dsX + DSTRIP_PAD, rowY, DSTRIP_CELL, DSTRIP_CELL,
                         DrawStripPlateFill(), DSTRIP_CLR_LABEL, DrawStripPlateFill(), "", tipGrip);
   dirty |= DrawStripFace(DrawStripGripIconName() + "C", s_dsX + DSTRIP_PAD, rowY,
                          DSTRIP_CELL, DSTRIP_CELL, "::Files\\Icons\\pnl_chip.bmp", tipGrip);
   dirty |= DrawStripFace(DrawStripGripIconName(), s_dsX + DSTRIP_PAD, rowY,
                          DSTRIP_CELL, DSTRIP_CELL, "::Files\\Icons\\bk_grip.bmp", tipGrip);
   string badgeTip = "This toolbar serves " + DrawStripTitle() +
                     " — hold the left button on a drawing to bring it up, click away to dismiss" +
                     DrawStripTipScope();
   // P-DRAW-66: the badge's band is the quick row — its ink sits on the row's own
   // centre (the retired writer put it 5px above it) and speaks the title rung.
   dirty |= DrawStripLblIn(DrawStripBadgeName(),
                           s_dsX + s_dsBadgeX, rowY, DSTRIP_CELL,
                           DrawStripTitle(), DSTRIP_CLR_LABEL, badgeTip, 9, true);
   //--- P-DRAW-66: the two group separators (identity | values | commands).
   for(int g = 0; g < 2; g++)
      dirty |= DrawStripRect(DrawStripSepName(g), s_dsX + s_dsSepX[g],
                             rowY + (DSTRIP_CELL - DSTRIP_SEP_H) / 2,
                             DSTRIP_SEP_W, DSTRIP_SEP_H, DSTRIP_CLR_LINE, Z_STRIP_ICON);

   //--- quick icon cells (icon-only; the colour cell is a swatch, no raster).
   //--- DIAG-135 (2026-10-02) — THE RARE ONE, CAUGHT BY ITS OWN PAINT.
   //--- User report: «بعضی وقتان … باکس اصلا رنگ نمیکره … گاهی به ندرت پیش میاد», and
   //--- then, asked to reproduce it: «الان من هر کاری میکنم اون حالت پیش نمیاد». That
   //--- pair is the whole shape of an intermittent, and it is not a bug to reproduce —
   //--- it is a bug to INSTRUMENT. MEASURED on the screenshot that came with it: THREE
   //--- cells whose interior measured EXACTLY the plate colour (nothing drawn at all),
   //--- and 148 px of empty row after them. The icons were deployed and had ink (both
   //--- measured, so neither), so the failure is not the art: it is a cell that PAINTED
   //--- NOTHING while the layout still reserved it.
   //--- So the paint checks its own invariant and writes the evidence the moment it is
   //--- false — whether or not anyone is looking, and months later. Three attempts at
   //--- this class already cost this project a day each (the `[BX…]` cuts); every one
   //--- of them guessed from a model while the live box disagreed. THE COST, honestly:
   //--- `res` and the seat are already in hand, so the check is a compare plus ONE
   //--- `ObjectFind` on the paint path — an interaction, never a tick — and the
   //--- signature is emitted once per DISTINCT state, so a healthy panel writes nothing
   //--- and a sick one writes one line instead of a flood. The file is flushed
   //--- (P-DRAW-126), so the answer is readable the next time it happens.
   string dsBad = "";
   int dsBadX = 0;
   int dsBadPainted = 0;
   for(int i = 0; i < DSTRIP_MAX_SLOTS; i++)
   {
      string on = DrawStripObjName(i);
      string ic = DrawStripIconName(i);
      bool live = (i < s_dsN);
      int slot = live ? DrawStripQuickSlotAt(s_dsKind, i) : -1;
      if(!live || slot < 0)
      {
          if(ObjectFind(0, on) >= 0) { ObjectDelete(0, on); dirty = true; }
          if(ObjectFind(0, ic) >= 0) { ObjectDelete(0, ic); dirty = true; }
          if(ObjectFind(0, ic + "C") >= 0) { ObjectDelete(0, ic + "C"); dirty = true; }
          if(ObjectFind(0, ic + "S") >= 0) { ObjectDelete(0, ic + "S"); dirty = true; }
          if(ObjectFind(0, ic + "C2") >= 0) { ObjectDelete(0, ic + "C2"); dirty = true; }
          if(ObjectFind(0, ic + "R") >= 0) { ObjectDelete(0, ic + "R"); dirty = true; }  // P-DRAW-64a2: the BORDER bar
          continue;
      }
      int x = s_dsX + s_dsCX[i];
      string res = DrawStripIconRes(slot, s_dsObj);
      string tip = DrawStripSlotTip(s_dsKind, slot, s_dsObj);
       //--- P-DRAW-64a (2026-09-27) — THE ONE COLOUR SEAT: A RING AROUND A CENTRE.
       //--- User order: «این دوتا باکس ... میشه یکی بشه» + «اونیکه برای رنگ بوردر
       //--- هستش رو ایکونش نباید وسط رنگی باشه باید دورش رنگ باشه». So the seat's own
       //--- button wears the BORDER colour and the nested 24px swatch wears the
       //--- interior's — the border really is AROUND — and a kind with no interior
       //--- shows the plate tone in the middle, i.e. a ring with a hole. Each layer
       //--- names its own role, because the hand lands on one of them (the tip and
       //--- the tap both read which).
      if(DrawStripIsColorSlot(slot))
      {
         bool merged = (slot == DRAW_SLOT_FILLCLR);
         //--- P-DRAW-64a2 (2026-10-02) — THE RING WAS 4 PIXELS OF TARGET. P-DRAW-64a
         //--- drew the border as the cell's 1px OUTLINE and the interior as the 24px
         //--- centre, so the seat named two roles and gave one of them a 32-24=4px
         //--- band: «از کجا رنگ بوردر رو عوض کنم» had no visible answer, and the only
         //--- other route was the popup's `cycle >>`, which walks all 29 product
         //--- targets. Two bars, each wearing ITS OWN colour and each half the cell,
         //--- is the same law with fair hands: the pointer lands on the mark it names.
         //--- The bars also stay INSIDE P-DRAW-66's budget (a whole 32x32 face of a
         //--- bright border colour is what it forbade; 28x13 is a third of that, and
         //--- it is less ink than the 24x24 centre it replaces).
         int sw = DSTRIP_SWATCH;   // B-05's 24px floor, the centre's own target
         int swx = x + (DSTRIP_CELL - sw) / 2, swy = rowY + (DSTRIP_CELL - sw) / 2;
         int bw = DSTRIP_CELL - 4, bh = (DSTRIP_CELL - 6) / 2;   // 28 x 13, 6px between
         int bx = x + 2, bty = rowY + 1, bby = rowY + 1 + bh + 6;
         //--- P-DRAW-BODY-UI: a single-role seat wears ITS OWN slot — the
         //--- handle's cell reads the handle, never the levels.
         bool isBody = (slot == DRAW_SLOT_BODYCOLOR);
         color bcol = DrawStripColorRead(s_dsObj, isBody ? DRAW_SLOT_BODYCOLOR : DRAW_SLOT_COLOR);
         color ccol = DrawStripColorFace(s_dsObj, DRAW_SLOT_FILLCLR);
         string rtip = DrawStripColorRingTip(s_dsObj, merged);
         string ctip = (merged ? DrawStripColorMidTip(s_dsObj) : rtip);
         if(isBody)
         {
            rtip = DrawStripSlotTip(s_dsKind, DRAW_SLOT_BODYCOLOR, s_dsObj);
            ctip = rtip;
         }
         bool bOpen = (s_dsPicker == (isBody ? DRAW_SLOT_BODYCOLOR : DRAW_SLOT_COLOR));
         if(merged)
         {
            //--- the cell, then TWO marks: the top bar is the BORDER's and the bottom
            //--- bar the INTERIOR's. Their names are the hit test's whole answer —
            //--- `DrawStripTap` asks the OBJECT the terminal reported, so a role can
            //--- never be guessed from a coordinate (P-DRAW-64a's own rule).
            dirty |= DrawStripBtn(on, x, rowY, DSTRIP_CELL, DSTRIP_CELL, DrawStripPlateFill(),
                                  DSTRIP_CLR_LABEL,
                                  bOpen ? DSTRIP_CLR_ACCENT : StrapRingInk(bcol, DSTRIP_CLR_PANEL),
                                  "", rtip);
            dirty |= DrawStripFace(ic + "C", x, rowY, DSTRIP_CELL, DSTRIP_CELL,
                                   bOpen ? "::Files\\Icons\\pnl_chip_gold.bmp"
                                         : "::Files\\Icons\\pnl_chip.bmp", rtip);
            dirty |= DrawStripBtn(ic + "R", bx, bty, bw, bh, bcol, DrawStripInkOn(bcol),
                                  (s_dsPicker == DRAW_SLOT_COLOR) ? DSTRIP_CLR_ACCENT
                                                                  : BioSwatchBorder(bcol, BIO_CLR_CARD),
                                  "", rtip);
            dirty |= DrawStripBtn(ic + "S", bx, bby, bw, bh, ccol, DrawStripInkOn(ccol),
                                  (s_dsPicker == DRAW_SLOT_FILLCLR) ? DSTRIP_CLR_ACCENT
                                                                    : BioSwatchBorder(ccol, BIO_CLR_CARD),
                                  "", ctip);
            if(ObjectFind(0, ic + "C2") >= 0) { ObjectDelete(0, ic + "C2"); dirty = true; }
            if(ObjectFind(0, ic) >= 0) { ObjectDelete(0, ic); dirty = true; }
            continue;
         }
         //--- one role only: the cell wears it whole, the centre stays the plate tone
         //--- (a ring with a hole), exactly as P-DRAW-64a left it.
         ccol = DrawStripPlateFill();
         ctip = rtip;
          //--- P-DRAW-66 — THE RING, NOT THE BLOCK. The seat's own button wore the
          //--- BORDER colour as its whole 32x32 face, so a bright border painted
          //--- 1024 px of pure red into a dark row (the crop that started this).
          //--- The cell is the plate's tone now and the border is its 1px OUTLINE —
          //--- the ring IS the rect's own border, so no bake was needed — with the
          //--- interior's swatch nested inside. 124 coloured px instead of 1024,
          //--- and the seat finally wears the same chip face as its neighbours (it
          //--- was the quick row's one ds_cell32).
          dirty |= DrawStripBtn(on, x, rowY, DSTRIP_CELL, DSTRIP_CELL, DrawStripPlateFill(),
                                DSTRIP_CLR_LABEL,
                                bOpen ? DSTRIP_CLR_ACCENT : StrapRingInk(bcol, DSTRIP_CLR_PANEL),
                                "", rtip);
          dirty |= DrawStripFace(ic + "C", x, rowY, DSTRIP_CELL, DSTRIP_CELL,
                                 bOpen ? "::Files\\Icons\\pnl_chip_gold.bmp"
                                       : "::Files\\Icons\\pnl_chip.bmp", rtip);
          dirty |= DrawStripBtn(ic + "S", swx, swy, sw, sw, ccol, DrawStripInkOn(ccol),
                                (s_dsPicker == DRAW_SLOT_FILLCLR) ? DSTRIP_CLR_ACCENT
                                                                  : BioSwatchBorder(ccol, BIO_CLR_CARD),
                                "", ctip);
          dirty |= DrawStripFace(ic + "C2", swx, swy, sw, sw, "::Files\\Icons\\ds_swatch24.bmp", ctip);
          if(ObjectFind(0, ic) >= 0) { ObjectDelete(0, ic); dirty = true; }   // the seat has no glyph
          continue;
       }
       color face = DrawStripPlateFill(), ink = DSTRIP_CLR_LABEL, rim = DrawStripPlateFill();
       bool chipOn = false;
       if(DrawStripSlotOn(slot, s_dsObj))
          chipOn = true;
       if(DrawStripHasPicker(slot))
          rim = (s_dsPicker == slot) ? DSTRIP_CLR_ACCENT : DSTRIP_CLR_PICK;
       else if(chipOn)
          //--- TV parity: an ON toggle wears the accent hairline (the preview's
          //--- `.scell.on{box-shadow:inset 0 0 0 1px rgba(255,194,71,.34)}`) on
          //--- top of the accent wash the chip below lays down.
          rim = DSTRIP_CLR_ACCENT;
       dirty |= DrawStripBtn(on, x, rowY, DSTRIP_CELL, DSTRIP_CELL, face, ink, rim, "", tip);
       dirty |= DrawStripFace(ic + "C", x, rowY, DSTRIP_CELL, DSTRIP_CELL,
                              chipOn ? "::Files\\Icons\\pnl_chip_gold.bmp" : "::Files\\Icons\\pnl_chip.bmp", tip);
       //--- a seat that was a COLOUR one up to this paint leaves no half behind:
       //--- two probes per non-colour cell, on the repaint path only.
       if(ObjectFind(0, ic + "S") >= 0)  { ObjectDelete(0, ic + "S"); dirty = true; }
       if(ObjectFind(0, ic + "C2") >= 0) { ObjectDelete(0, ic + "C2"); dirty = true; }
       if(ObjectFind(0, ic + "R") >= 0)  { ObjectDelete(0, ic + "R"); dirty = true; }  // P-DRAW-64a2
       dirty |= DrawStripFace(ic, x, rowY, DSTRIP_CELL, DSTRIP_CELL, res, tip);
       dsBadPainted++;
       //--- DIAG-135: a raster seat MUST leave its glyph on the chart, and a seat with
       //--- no raster and no swatch is invisible BY CONSTRUCTION — which is exactly
       //--- what the screenshot measured. The first offender is named; the rest would
       //--- only repeat it.
       if(res == "" || ObjectFind(0, ic) < 0)
       {
          if(dsBad == "")
          {
             dsBad = "QUICKCELL slot=" + IntegerToString(slot) + " res=\"" + res + "\"";
             dsBadX = x;
          }
       }

   }

   //--- chrome actions: more / gear / pin / del.
   for(int a = 0; a < DSTRIP_ACT_N; a++)
   {
      string an = DrawStripActName(a), ai = DrawStripActIconName(a);
      int x = s_dsX + DrawStripActX(a);
      string tip = DrawStripActTip(a);
       color face = DrawStripPlateFill(), ink = DSTRIP_CLR_LABEL, rim = DrawStripPlateFill();
       bool chipOn = false;
       //--- P-DRAW-66: the chrome wears a rim ONLY while it is active (closed more
       //--- and gear were rimmed into a constant glow), and the bin wears the same
       //--- chip as its neighbours with the destructive INK as its only colour.
       if(a == DSTRIP_ACT_DEL) ink = DSTRIP_CLR_DEL_INK;
       if(a == DSTRIP_ACT_PIN && s_dsPinned) { rim = DSTRIP_CLR_ACCENT; chipOn = true; }
       if(a == DSTRIP_ACT_MORE && s_dsPicker == DSTRIP_MORE) { rim = DSTRIP_CLR_ACCENT; chipOn = true; }
       if(a == DSTRIP_ACT_GEAR && s_dsGear != 0) { rim = DSTRIP_CLR_ACCENT; chipOn = true; }
       dirty |= DrawStripBtn(an, x, rowY, DSTRIP_CELL, DSTRIP_CELL, face, ink, rim, "", tip);
       dirty |= DrawStripFace(ai + "C", x, rowY, DSTRIP_CELL, DSTRIP_CELL,
                              chipOn ? "::Files\\Icons\\pnl_chip_gold.bmp" : "::Files\\Icons\\pnl_chip.bmp", tip);
       string ares = DrawStripActRes(a);
      dirty |= DrawStripFace(ai, x, rowY, DSTRIP_CELL, DSTRIP_CELL, ares, tip);
      dsBadPainted++;
      //--- DIAG-135: the chrome row is the other half of the same screenshot — the
      //--- black square 148 px in was an ACTION cell, not a value cell, so the quick-row
      //--- check alone would have called the row healthy.
      if(ares == "" || ObjectFind(0, ai) < 0)
      {
         if(dsBad == "")
         {
            dsBad = "ACTCELL a=" + IntegerToString(a) + " res=\"" + ares + "\"";
            dsBadX = x;
         }
      }

   }

   //--- DIAG-135: one line per DISTINCT state, not one per paint. The signature carries
   //--- what the next run needs and nothing it would only re-derive: the kind, the
   //--- reserved-vs-painted count (the 148 px gap is a COUNT disagreement, so the count
   //--- is the fact), and the offending seat's own name and raster.
   if(dsBad != "")
   {
      string sig = IntegerToString((int)s_dsKind) + "|" + dsBad + "|" +
                   IntegerToString(s_dsN) + "|" + IntegerToString(dsBadX);
      if(sig != dsWitnessSig)
      {
         dsWitnessSig = sig;
         DrawStripDiagEmit("[drawstrip] ROWBLANK " + sig +
                           " painted=" + IntegerToString(dsBadPainted) +
                           " x=" + IntegerToString(dsBadX));
      }
   }
   else if(dsWitnessSig != "") dsWitnessSig = "";   // recovered: arm the line again next time

   //--- P-PAL-21 (2026-10-02) — FAMILY 2 IS THE COLOUR BOARD'S PLATE, and the board is
   //--- gone, so nothing paints family 2 any more. The probe stays, unconditional and
   //--- in the same place: one `ObjectFind` per paint, and a plate a PATH left behind
   //--- (or an older build left on this chart) can never sit under the strip again.
   //--- Same law as P-DRAW-75's, one answer stronger — there is no state to consult.
   if(ObjectFind(0, DrawStripBoardBgName()) >= 0)
      dirty |= DrawStripSkinPurgeAt(2);

   //--- popover block (ONE at a time).
   int contentW = s_dsW - 2 * DSTRIP_PAD;
   //--- P-PAL-21 (2026-10-02) — THE BOARD'S OWN BRANCH IS GONE. This was the whole
   //--- colour board: its plate, its header (grip, name, pin, close, the two role
   //--- segments, the page arrows and the «1/2»), the 8x8 grid, the RECENT band, the
   //--- HEX field, the opacity bar and the family captions with the HSV studio under
   //--- them. A colour seat cannot be the picker since P-PAL-19 — the quick row's
   //--- colour cell asks the CARDS' palette, and that popup's own TR track writes the
   //--- drawing's slot alpha (P-PAL-19) — so every pixel below was painted for a
   //--- surface no code path reaches. What remains is the list picker: the rows, the
   //--- chip, the rail and the MORE page.
   if(s_dsPicker != DSTRIP_PICK_NONE)
   {
      //--- P-PAL-21: the slot switch no longer has board chrome to drop.
      //--- P-DRAW-75: the board's plate goes with it, and the ONE decision above the
      //--- branches (family 2 lives iff a colour board is open) has already asked.
      for(int r = 0; r < DSTRIP_PICK_MAX; r++)
      {
         string pn = DrawStripPickName(r), pi = DrawStripPickIconName(r),
                pt = DrawStripPickLabelName(r), pc = DrawStripPickChipName(r),
                pr = DrawStripPickRailName(r);
         if(r >= s_dsPN)
         {
            if(ObjectFind(0, pn) >= 0) { ObjectDelete(0, pn); dirty = true; }
            if(ObjectFind(0, pi) >= 0) { ObjectDelete(0, pi); dirty = true; }
            if(ObjectFind(0, pt) >= 0) { ObjectDelete(0, pt); dirty = true; }
            if(ObjectFind(0, pc) >= 0) { ObjectDelete(0, pc); dirty = true; }
            if(ObjectFind(0, pr) >= 0) { ObjectDelete(0, pr); dirty = true; }
            continue;
         }
         int py = s_dsY + s_dsPY[r];
         int px = s_dsX + DSTRIP_PAD;
         bool cur = DrawStripPopRowIsCur(r);
         string res = DrawStripPopRowRes(r);
         string txt = DrawStripPopRowText(r);
         string tip = DrawStripPopRowTip(r);
         bool dimmed = (s_dsPicker == DSTRIP_MORE && s_dsMoreKind[r] == DSTRIP_MK_UNDO && !s_duValid);
         color ink = dimmed ? DSTRIP_CLR_TITLE : DSTRIP_CLR_LABEL;
         if(s_dsPicker == DSTRIP_MORE && s_dsMoreKind[r] == DSTRIP_MK_APPLYALL)
            ink = DSTRIP_CLR_ACCENT;
         color popTone = StrapCellTone(s_dsPY[r], DSTRIP_STRIP_BODY_TOP, DSTRIP_STRIP_GRID_TOP, s_dsH);   // P-DRAW-69
         dirty |= DrawStripBtn(pn, px, py, contentW, DSTRIP_PICK_ROW,
                               popTone, ink, popTone, "", tip);
         dirty |= DrawStripFace(pr, px, py, 2, DSTRIP_PICK_ROW,
                                cur ? "::Files\\Icons\\pnl_rail_gold.bmp" : "", tip);
         if(res != "")
         {
            dirty |= DrawStripFace(pc, px, py + 10, 22, 22,
                                   cur ? "::Files\\Icons\\pnl_chip_gold.bmp" : "::Files\\Icons\\pnl_chip.bmp", tip);
            dirty |= DrawStripFace(pi, px - 2, py + 8, 26, 26, res, tip);
         }
         int labelX = px + (res == "" ? 12 : 32);
         dirty |= DrawStripLblIn(pt, labelX, py, DSTRIP_PICK_ROW,
                                 PnlFit(txt, 9, contentW - (labelX - px) - 12),
                                 ink, tip, 9, true);   // P-DRAW-68: the cards' row label
      }
   }
   else
   {
      //--- P-DRAW-75 (2026-09-28): the board's PLATE is taken by the ONE decision
      //--- above the branches, so this branch carries only the board's own CELLS.
      //--- P-DRAW-73 put the purge here, on a bool that could not see a plate; the
      //--- reported artefact is the empty 42px banded tower under the panel (ten
      //--- bands of family 2 at 328 wide, no content, nothing owning them).
      for(int r = 0; r < DSTRIP_PICK_MAX; r++)
      {
         bool gone = false;
         if(ObjectFind(0, DrawStripPickName(r)) >= 0)
         { ObjectDelete(0, DrawStripPickName(r)); gone = true; }
         if(ObjectFind(0, DrawStripPickIconName(r)) >= 0)
         { ObjectDelete(0, DrawStripPickIconName(r)); gone = true; }
         if(ObjectFind(0, DrawStripPickLabelName(r)) >= 0)
         { ObjectDelete(0, DrawStripPickLabelName(r)); gone = true; }
         if(ObjectFind(0, DrawStripPickChipName(r)) >= 0)
         { ObjectDelete(0, DrawStripPickChipName(r)); gone = true; }
         if(ObjectFind(0, DrawStripPickRailName(r)) >= 0)
         { ObjectDelete(0, DrawStripPickRailName(r)); gone = true; }
         if(ObjectFind(0, DrawStripPickGlassName(r)) >= 0)
         { ObjectDelete(0, DrawStripPickGlassName(r)); gone = true; }
         if(gone) dirty = true;
      }
   }

   //--- P-DRAW-32: the SETTINGS PANEL — its own plate, at its own origin. Placed
   //--- FIRST (plate, head, tabs, rows and the carry all read one origin), then
   //--- painted; a shut panel takes its plate away with its controls.
   if(s_dsGear != 0)
   {
      //--- P-DRAW-73 (2026-09-28): the panel's plate and its content both read the
      //--- LAYOUT (`s_dsGearH` + the item arrays), and only a tap runs one. An open
      //--- panel with no layout would paint its controls onto a bare chart, so the
      //--- state is named once instead of being drawn wrong (F2: the log IS a channel).
      if(s_dsGearH <= 0)
      {
         static bool said = false;
         if(!said)
         {
            said = true;
            Print("[drawstrip] panel open with no layout (gearH=", s_dsGearH,
                  ") — a path changed the content without DrawStripLayout()");
         }
      }
      DrawStripPlaceGear();
      dirty |= DrawStripGearPlate();
      dirty |= DrawStripGearPaint();
   }
   else if(ObjectFind(0, DrawStripGearBgName()) >= 0)
   {
      //--- P-DRAW-75: the gate is the plate itself, not a flag about it (the
      //--- board's own decision above). It is owed nothing when it was never painted,
      //--- so the popover's own path still probes nothing it does not own.
      dirty |= DrawStripGearPurge();
      dirty |= DrawStripGearSkinPurge();
   }

   DrawStripPublishRect();   // P-DRAW-31: the cards' placement reads the plate here
   if(dirty) ChartRedraw();
}

//--- P-DRAW-20 (2026-09-24) — THE FRESH PLACEMENT IS THE DRAWING'S OWN CORNER.
//---
//--- User order: «به صورت پیش فرض استریپ در جای هوشمند ظاهر بشه». The hold that
//--- opens the strip fires ON the drawing, so the old +12/+12 CURSOR offset parked
//--- the plate on top of the very object it serves — and near the right/bottom
//--- edge the clamp then pushed it further onto that object, never off it. The box
//--- strip's own rule (P-BK-27) is the precedent this wears: THE TOOLBAR NEVER
//--- COVERS THE HANDLE IT BELONGS TO. P-DRAW-41 asks it ONE time only: from then
//--- on the plate wears its home and no placement runs.
//---
//--- P-DRAW-41 (2026-09-25) — THE HOME'S OWNERS. One reader pair and one clamp, so
//--- "where does the strip live" and "is it still reachable" each have one answer.
bool DrawStripHomeGet(int &x, int &y)
{
   if(s_dsHomeX < 0 || s_dsHomeY < 0) return false;
   x = s_dsHomeX;
   y = s_dsHomeY;
   return true;
}

void DrawStripHomeSet(const int x, const int y)
{
   if(x < 0 || y < 0) return;
   s_dsHomeX = x;
   s_dsHomeY = y;
}

//--- A shrunk window must never strand the home off-screen (E-05: no dead zone).
//--- While the strip is open this is ALL a zoom or a scroll still owes the plate:
//--- window arithmetic, zero projections, and a paint only if it really moved.
void DrawStripHomeClamp()
{
   if(!s_dsOpen || s_dsHomeX < 0) return;
   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0); if(cw <= 0) cw = 1920;
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0); if(ch <= 0) ch = 1080;
   int nx = s_dsHomeX, ny = s_dsHomeY;
   if(nx > cw - s_dsW - 4) nx = cw - s_dsW - 4;
   if(ny > ch - s_dsH - 4) ny = ch - s_dsH - 4;
   if(nx < 4) nx = 4;
   if(ny < 4) ny = 4;
   if(nx == s_dsHomeX && ny == s_dsHomeY) return;
   s_dsHomeX = nx; s_dsHomeY = ny;
   if(nx == s_dsX && ny == s_dsY) return;
   s_dsX = nx; s_dsY = ny;
   DrawStripLayout();
   DrawStripPaint();
}
//---
//--- So the fresh spot is measured off the drawing itself, not the hand: its pixel
//--- box (every anchor that projects — 1 for a hline, 2 for a segment/box, 3 for a
//--- channel/fork) answers four candidates — above its top edge, below its bottom
//--- edge, left of it, right of it — all right/edge-aligned so the plate sits where
//--- the eye expects it, and the FIRST candidate that needs no clamping AND does
//--- not overlap the drawing wins. A drawing too big for the window has no such
//--- spot: then the reading order stands (above, else below) and the result is
//--- clamped, never left inside the drawing by accident. And a drawing whose
//--- anchors do not project at all (off-window) falls back to the PRE-P-DRAW-20
//--- spot: a placement that cannot measure the object must not invent one.
//--- The user's own carry rewrites the HOME (`DrawStripHomeSet`), and the home wins
//--- every open after it (P-DRAW-41).
#define DSTRIP_PLACE_GAP 14    // clear air between the drawing's pixel box and the plate
void DrawStripPlaceFresh(const string name, const int mx, const int my, int &x, int &y)
{
   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0); if(cw <= 0) cw = 1920;
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0); if(ch <= 0) ch = 1080;
   int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
   bool have = DrawStripDrawingBox(name, x1, y1, x2, y2);   // P-DRAW-40: one owner
   if(!have)
   {
      x = mx + 12; y = my + 12;   // the pre-P-DRAW-20 spot (unmeasurable drawing)
      int cm0 = 4 + DSTRIP_SKIN_M;   // P-DRAW-29: the skin stands past the content
      if(x < cm0) x = cm0;
      if(y < cm0) y = cm0;
      if(x > cw - s_dsW - cm0) x = cw - s_dsW - cm0;
      if(y > ch - s_dsH - cm0) y = ch - s_dsH - cm0;
      return;
   }
   int cx[4], cy[4];
   cx[0] = x2 - s_dsW;                    cy[0] = y1 - s_dsH - DSTRIP_PLACE_GAP;   // above
   cx[1] = x2 - s_dsW;                    cy[1] = y2 + DSTRIP_PLACE_GAP;           // below (P-BK-27)
   cx[2] = x1 - s_dsW - DSTRIP_PLACE_GAP; cy[2] = y1;                              // left of it
   cx[3] = x2 + DSTRIP_PLACE_GAP;         cy[3] = y1;                              // right of it
   // P-DRAW-31: and the OPEN CARD is a third thing every spot must clear — the user's
   // rule is that two surfaces never sit on one pixel («جایی که روی هم نیافتن»). The
   // card publishes its own rect (g_UIPanelR*, P-UI-98r) for exactly this kind of
   // reader; when no card is open the terms are inert. Priority: a spot that clears
   // BOTH beats one that only clears the drawing, which beats the clamped fallback.
   bool card = (g_UIPanelRX >= 0 && g_UIPanelRW > 0 && g_UIPanelRH > 0);
   int fb = -1;
   for(int c = 0; c < 4; c++)
   {
      int px = cx[c], py = cy[c];
      int cm = 4 + DSTRIP_SKIN_M;   // P-DRAW-29: keep the skin, not just the content
      bool onWin  = (px >= cm && py >= cm && px <= cw - s_dsW - cm && py <= ch - s_dsH - cm);
      bool misses = (px + s_dsW <= x1 || px >= x2 || py + s_dsH <= y1 || py >= y2);
      bool onCard = card && !(px + s_dsW <= g_UIPanelRX - DSTRIP_PLACE_GAP ||
                              px >= g_UIPanelRX + g_UIPanelRW + DSTRIP_PLACE_GAP ||
                              py + s_dsH <= g_UIPanelRY - DSTRIP_PLACE_GAP ||
                              py >= g_UIPanelRY + g_UIPanelRH + DSTRIP_PLACE_GAP);
      if(onWin && misses && !onCard) { x = px; y = py; return; }
      if(onWin && !onCard && fb < 0) fb = c;   // clears the card, not the drawing
   }
   if(fb >= 0) { x = cx[fb]; y = cy[fb]; return; }
   x = cx[0]; y = cy[0];   // no clean spot: reading order (above, else below), clamped
   if(y < 4 + DSTRIP_SKIN_M)
   {
      y = cy[1];
      if(y > ch - s_dsH - 4 - DSTRIP_SKIN_M) y = ch - s_dsH - 4 - DSTRIP_SKIN_M;
   }
   if(x < 4 + DSTRIP_SKIN_M) x = 4 + DSTRIP_SKIN_M;
   if(y < 4 + DSTRIP_SKIN_M) y = 4 + DSTRIP_SKIN_M;
   if(x > cw - s_dsW - 4 - DSTRIP_SKIN_M) x = cw - s_dsW - 4 - DSTRIP_SKIN_M;
   if(y > ch - s_dsH - 4 - DSTRIP_SKIN_M) y = ch - s_dsH - 4 - DSTRIP_SKIN_M;
}

//--- OPEN AT CURSOR (P-DRAW-13, preview parity): the trigger's press point answers
//--- where, clamped like the preview's openStripAt (+12, +12, 4px margins).
//--- P-DRAW-20: the CURSOR only answers when the drawing itself cannot be measured
//--- (see `DrawStripPlaceFresh`). P-DRAW-41: and only on the ONE open that has no
//--- home yet — after that the plate wears the home and no placer runs at all.
bool DrawStripOpenAt(const string name, const int mx, const int my)
{
   if(name == "" || ObjectFind(0, name) < 0) return false;
   EDrawKind k = DrawKindOf(name);
   if(k == DK_NONE) return false;
   // P-DRAW-41 (2026-09-25): the SAME object again is a re-state, not a move — the
   // plate wears its home and nothing is re-measured. This is what P-DRAW-37's ride
   // shrank to once the home existed: the rebuild it replaced deleted and re-created
   // the whole family (~40 objects) at the drawing's own drag cadence.
   if(s_dsOpen && s_dsObj == name)
   {
      if(s_dsKind == DK_RECT) BoxMidSync(name);   // P-DRAW-21: the mid rides this event
      return true;
   }
   int keepPicker = s_dsPicker, keepGear = s_dsGear;
   bool keepPin = s_dsPinned;
   // P-DRAW-41: MEASURE BEFORE THE CLOSE — an object that cannot project must not
   // leave the surface torn down (J-02: nothing may advertise a state that did not
   // happen). The ride above keeps what was already open; this is the fresh path.
   int ax = 0, ay = 0;
   if(!DrawAnchorXY(name, 0, ax, ay))
   { Print("[drawstrip] close: anchor projection failed on \"", name, "\""); return false; }
   DrawStripClose();
   // P-DRAW-09b: THE GROUP IS TAKEN HERE, ONCE, and AFTER the close (a close
   // drops the group, because a group belongs to an open strip). The terminal's
   // own selection is the user's statement of "these", and an open is the only
   // moment it can legitimately change — a live read would walk the object list
   // on a stream, and a group that shifted mid-edit is worse than a stale one.
   DrawSelSnapshot(name);
   //--- P-DRAW-74: THE TERMINAL'S OWN DIALOG IS A SECOND WRITER. MT4's properties
   //--- window stores width and style straight onto the object and never passes
   //--- `DrawSlotWrite`, so an impossible pair (3 px + Dash) can be born there. One
   //--- ask on the open - the ONE place every served drawing passes - and the pair
   //--- is legal before the panel ever prints a caption for it.
   DrawStylePairCoerce(name);
   s_dsKind = k;
   s_dsObj = name;
   s_dsOpen = true;
   s_dsPicker = DSTRIP_PICK_NONE;
   if((keepPicker != DSTRIP_PICK_NONE) &&
      (keepPicker == DSTRIP_MORE || DrawStripHasPicker(keepPicker)))
      s_dsPicker = keepPicker;
   s_dsGear = 0;
   s_dsGearPressSpent = false;   // P-DRAW-84: a spent flag outlives its panel
   if(keepGear != 0) s_dsGear = keepGear;
   else
   {
      // fresh open: compact quick row only, no gear panel.
      s_dsTplNameArmed = false;
   }
   s_dsPinned = keepPin;
   s_dsN = DrawStripQuickCount(k);
   DrawStripLayout();
   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0); if(cw <= 0) cw = 1920;
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0); if(ch <= 0) ch = 1080;
   // P-DRAW-41 (2026-09-25): the HOME is the placement, and the first open on a
   // chart is the only one without one — it measures the drawing through the
   // P-DRAW-20 placer once (the drawing's own corner, never the cursor under the
   // hand) and that answer becomes the home for every open after it.
   if(!DrawStripHomeGet(s_dsX, s_dsY)) DrawStripPlaceFresh(name, mx, my, s_dsX, s_dsY);
   if(s_dsX < 4) s_dsX = 4;
   if(s_dsY < 4) s_dsY = 4;
   if(s_dsX > cw - s_dsW - 4) s_dsX = cw - s_dsW - 4;
   if(s_dsY > ch - s_dsH - 4) s_dsY = ch - s_dsH - 4;
   DrawStripHomeSet(s_dsX, s_dsY);   // P-DRAW-41: what was placed (or clamped) IS the home
   if(k == DK_RECT) BoxMidSync(name);   // P-DRAW-21: the drag/zoom ride moves the mid too
   FibPenSync(name, false);   // P-DRAW-74b: an open re-converges the pair with the drawing
   DrawStripPaint();
   return true;
}
bool DrawStripOpen(const string name)
{
   // P-DRAW-20: no cursor in hand is the NORMAL case — the measured spot is what a
   // fresh open wears and `mx` only answers when the drawing cannot be measured.
   // P-DRAW-41: both only matter for the first open; a home answers every other.
   return DrawStripOpenAt(name, -1, -1);
}

//--- P-DRAW-09b (retired 2026-10-03): ONE write for a value, delivered to the
//--- SERVED DRAWING. The loop is kept because every reader of `DrawSelCount` keeps
//--- its exact signature, and the store now holds one name (see `DrawSelSnapshot`) —
//--- so this iterates a list of ONE. The automatic fan-out that made a colour tap
//--- on one fibo land on the other is gone from every write path that came through
//--- here. The learning half lives in `DrawSlotWrite` (P-DRAW-01c).
//--- Every caller pushes undo FIRST (single-step looks).
int DrawStripWriteValue(const int slot, const double v)
{
   //--- P-DRAW-64a: the box's own 50 % needs no "show the interior" rule — it moves
   //--- the DRAWING's far anchor, so it is visible with the fill off, on, or never
   //--- (the user's own correction: «۵۰ درصد باکس فقط میخوام، fill بهکارم نمیاد»).
   DrawSelPrune();
   int n = DrawSelCount();
   if(n <= 0)
   {
      if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return 0;
      return (DrawSlotWrite(s_dsObj, slot, v) ? 1 : 0);
   }
   int done = 0;
   for(int i = 0; i < n; i++)
   {
      string nm = DrawSelAt(i);
      if(nm == "" || ObjectFind(0, nm) < 0) continue;
      if(DrawSlotWrite(nm, slot, v)) done++;
   }
   // DIAG-141 (2026-10-03) — THE GROUP LEAVES ITS NUMBER. One tap fanning out
   // to several drawings («رنگ یکی را عوض میکنم روی دیگری هم اعمال میشه») is
   // otherwise indistinguishable from a second writer. Discrete taps only.
   // P-DRAW-09b retired the same day: `n > 1` is now IMPOSSIBLE (`DrawSelSnapshot`
   // holds one name), so the line can no longer fire — which is the point. It stays
   // as the witness that proves it: a fan-out reaching a second drawing would have
   // to be a second WRITER, and that writer would have to go through here to be seen.
   if(n > 1)
      DrawStripDiagEmit("[drawstrip] GROUP n=" + IntegerToString(n) +
                        " slot=" + IntegerToString(slot) + " obj=\"" + s_dsObj + "\"");
   return done;
}

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-13 — SINGLE-STEP UNDO. The pre-mutation looks of the group (capped),
// the held drawing's level set, and a duplicate's copy name. Every mutating
// path pushes FIRST; undo pops once. Trash is not undoable (no undelete).
// ══════════════════════════════════════════════════════════════════════════
void DrawStripUndoLook(const string nm, const int i)
{
   s_duName[i] = nm;
   s_duClr[i] = (color)(int)DrawSlotRead(nm, DRAW_SLOT_COLOR);
   s_duW[i] = (int)DrawSlotRead(nm, DRAW_SLOT_WIDTH);
   s_duSt[i] = (int)DrawSlotRead(nm, DRAW_SLOT_STYLE);
   s_duFill[i] = (DrawSlotRead(nm, DRAW_SLOT_FILL) > 0.5 ? 1 : 0);
   //--- P-DRAW-64: undo restores the interior too — a 50% fill the user did not
   //--- want must come back off in ONE step like every other look change.
   s_duFillClr[i] = (color)(int)DrawSlotRead(nm, DRAW_SLOT_FILLCLR);
   s_duFillOp[i]  = DrawSlotAlphaGet(nm, DRAW_SLOT_FILLCLR);
   s_duRay[i] = (int)DrawSlotRead(nm, DRAW_SLOT_RAY);
   s_duFont[i] = (int)DrawSlotRead(nm, DRAW_SLOT_FONT);
   s_duGlyph[i] = (int)DrawSlotRead(nm, DRAW_SLOT_GLYPH);
   s_duBack[i] = (DrawSlotRead(nm, DRAW_SLOT_BACK) > 0.5 ? 1 : 0);
   //--- P-DRAW-BODY-UI: the handle rides the same single-step undo (same seats).
   if(DrawSlotAvailable(DrawKindOf(nm), DRAW_SLOT_BODYCOLOR))
   {
      s_duBodyClr[i] = (color)(int)DrawSlotRead(nm, DRAW_SLOT_BODYCOLOR);
      s_duBodyW[i] = (int)DrawSlotRead(nm, DRAW_SLOT_BODYWIDTH);
      s_duBodySt[i] = (int)DrawSlotRead(nm, DRAW_SLOT_BODYSTYLE);
   }
}
void DrawStripUndoPush()
{
   DrawSelPrune();
   s_duN = 0;
   int n = DrawSelCount();
   if(n <= 0 && s_dsObj != "" && ObjectFind(0, s_dsObj) >= 0)
   {
      DrawStripUndoLook(s_dsObj, 0);
      s_duN = 1;
   }
   else
   {
      for(int i = 0; i < n && s_duN < DSTRIP_UNDO_MAX; i++)
      {
         string nm = DrawSelAt(i);
         if(nm == "" || ObjectFind(0, nm) < 0) continue;
         DrawStripUndoLook(nm, s_duN);
         s_duN++;
      }
   }
   s_duLvN = 0;
   if(s_dsObj != "" && ObjectFind(0, s_dsObj) >= 0 && DrawKindHasLevels(s_dsKind))
   {
      int nl = DrawLevelCount(s_dsObj);
      for(int l = 0; l < nl && s_duLvN < DSTRIP_UNDO_LV; l++)
      {
         s_duLvT[s_duLvN] = ObjectGetString(0, s_dsObj, OBJPROP_LEVELTEXT, l);   // P-LVL-TEXT
         s_duLvV[s_duLvN] = DrawLevelValue(s_dsObj, l);
         s_duLvC[s_duLvN] = (color)(int)ObjectGetInteger(0, s_dsObj, OBJPROP_LEVELCOLOR, l);
         s_duLvW[s_duLvN] = FibPenLogicalWidth(s_dsObj, l);   // P-DRAW-74b: snapshot the remembered width
         s_duLvS[s_duLvN] = (int)ObjectGetInteger(0, s_dsObj, OBJPROP_LEVELSTYLE, l);
         s_duLvN++;
      }
   }
   s_duCopy = "";
   s_duValid = true;
}
bool DrawStripUndoPop()
{
   if(!s_duValid) return false;
   if(s_duCopy != "")
   {
      if(ObjectFind(0, s_duCopy) >= 0) ObjectDelete(0, s_duCopy);
      if(s_duCopy == s_dsObj)
      { Print("[drawstrip] close: undo popped the strip's own copy"); DrawStripClose(); ChartRedraw(); s_duValid = false; return true; }
      s_duValid = false;
      DrawStripPaint();
      ChartRedraw();
      return true;
   }
   for(int i = 0; i < s_duN; i++)
   {
      string nm = s_duName[i];
      if(nm == "" || ObjectFind(0, nm) < 0) continue;
      DrawSlotWrite(nm, DRAW_SLOT_COLOR, (double)(int)s_duClr[i]);
      DrawSlotWrite(nm, DRAW_SLOT_WIDTH, (double)s_duW[i]);
      DrawSlotWrite(nm, DRAW_SLOT_STYLE, (double)s_duSt[i]);
      if(DrawSlotAvailable(DrawKindOf(nm), DRAW_SLOT_FILL))
         DrawSlotWrite(nm, DRAW_SLOT_FILL, (double)s_duFill[i]);
      if(DrawSlotAvailable(DrawKindOf(nm), DRAW_SLOT_RAY))
         DrawSlotWrite(nm, DRAW_SLOT_RAY, (double)s_duRay[i]);
      if(DrawSlotAvailable(DrawKindOf(nm), DRAW_SLOT_FONT))
         DrawSlotWrite(nm, DRAW_SLOT_FONT, (double)s_duFont[i]);
      if(DrawSlotAvailable(DrawKindOf(nm), DRAW_SLOT_GLYPH))
         DrawSlotWrite(nm, DRAW_SLOT_GLYPH, (double)s_duGlyph[i]);
      DrawSlotWrite(nm, DRAW_SLOT_BACK, (double)s_duBack[i]);
      if(DrawSlotAvailable(DrawKindOf(nm), DRAW_SLOT_FILLCLR))
      {
         DrawSlotWrite(nm, DRAW_SLOT_FILLCLR, (double)(int)s_duFillClr[i]);
         DrawSlotOpacitySet(nm, s_duFillOp[i], DRAW_SLOT_FILLCLR);
      }
      if(DrawSlotAvailable(DrawKindOf(nm), DRAW_SLOT_BODYCOLOR))
      {
         DrawSlotWrite(nm, DRAW_SLOT_BODYCOLOR, (double)(int)s_duBodyClr[i]);
         DrawSlotWrite(nm, DRAW_SLOT_BODYWIDTH, (double)s_duBodyW[i]);
         DrawSlotWrite(nm, DRAW_SLOT_BODYSTYLE, (double)s_duBodySt[i]);
      }
   }
   if(s_duLvN > 0 && s_dsObj != "" && ObjectFind(0, s_dsObj) >= 0 && DrawKindHasLevels(s_dsKind))
   {
      FibPenTagDrop(s_dsObj);   // P-DRAW-74b: restored truth spends the memory
      ObjectSetInteger(0, s_dsObj, OBJPROP_LEVELS, s_duLvN);
      for(int l = 0; l < s_duLvN; l++)
      {
         ObjectSetDouble(0, s_dsObj, OBJPROP_LEVELVALUE, l, s_duLvV[l]);
         ObjectSetInteger(0, s_dsObj, OBJPROP_LEVELCOLOR, l, s_duLvC[l]);
         ObjectSetInteger(0, s_dsObj, OBJPROP_LEVELWIDTH, l, s_duLvW[l]);
         ObjectSetInteger(0, s_dsObj, OBJPROP_LEVELSTYLE, l, s_duLvS[l]);
         ObjectSetString(0, s_dsObj, OBJPROP_LEVELTEXT, l, s_duLvT[l]);   // P-LVL-TEXT
      }
      FibPenSync(s_dsObj, false);   // P-DRAW-74b: the undo restores truth, the pair follows it
   }
   s_duValid = false;
   DrawStripPaint();
   ChartRedraw();
   return true;
}
//--- a whole LOOK onto the group (template rows, more + gear): undoable, learned.
bool DrawStripPresetApplyGroup(const int row)
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   EDrawKind k = s_dsKind;
   if(k == DK_NONE) return false;
   //--- P-DRAW-76: `row` IS the slot id (both list builders pass one), so the guard is the slot
   //--- range plus "is it filled" — never the count, which a cleared slot turns into a lie.
   if(row < 0 || row >= DRAW_PRESET_MAX || DrawPresetName(k, row) == "") return false;
   //--- P-DRAW-76: SHIFT turns the same click into a DELETE of the user's own template
   //--- (`UIMagnetModifierDown` is the project's ONE Shift reader, P-BK-66). A built-in refuses,
   //--- and its tooltip says so instead of pretending the click did something.
   if(UIMagnetModifierDown())
   {
      if(DrawPresetIsBuiltin(row) || !DrawPresetClear(k, row)) return false;
      s_dsTpl[k] = -1;   // nothing is applied any more (no row can match -1)
      DrawStripPaint();
      ChartRedraw();
      return true;
   }
   DrawStripUndoPush();
   DrawSelPrune();
   int gn = DrawSelCount();
   if(gn > 0) { for(int j = 0; j < gn; j++) DrawPresetApply(DrawSelAt(j), row); }
   else DrawPresetApply(s_dsObj, row);
   //--- P-DRAW-64a: a preset re-inks the border, so a box wearing its level gets the
   //--- new blend at once — not on the pump's next pass. One guarded call per member.
   BoxMidSyncGroup();
   s_dsTpl[k] = row;
   return true;
}
//--- "New <kind> wears this look": learn the chart's current look into the
//--- kind's memory WITHOUT changing the drawing (same-value writes).
void DrawStripLearnCurrent()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return;
   EDrawKind k = s_dsKind;
   if(k == DK_NONE) return;
   for(int s = 0; s < DRAW_SLOT_N; s++)
   {
      if(s == DRAW_SLOT_MORE || s == DRAW_SLOT_LOCK || s == DRAW_SLOT_BACK) continue;
      //--- P-DRAW-64a: the level and the travelling edge are ARRANGEMENTS, not looks —
      //--- "learn the look" must not touch them, and same-value writes on them would
      //--- cost two description reads for a guaranteed no-op.
      if(s == DRAW_SLOT_BOXHALF || s == DRAW_SLOT_EXTEND) continue;
      if(!DrawSlotAvailable(k, s)) continue;
      DrawSlotWrite(s_dsObj, s, DrawSlotRead(s_dsObj, s));
   }
}
#endif // DRAW_STRIP_PAINT_MQH
// DrawStrip_Tap.mqh - DrawStrip split 2026-09-29: exact lines 6239-7018 of DrawStrip.mqh, byte-identical, zero renames.
#ifndef DRAW_STRIP_TAP_MQH
#define DRAW_STRIP_TAP_MQH


//--- P-DRAW-118 (2026-10-01) — A COLOUR HAS ONE OWNER. The palette cell, the
//--- panel's quick swatch and the board's HEX field all end in this write: RECENT,
//--- undo, the fill's own show group, the value, and the level's border sync. One
//--- place, so a new face for a colour cannot miss a step the old one took.
bool DrawStripColorCommit(const int slot, const color c)
{
   if(!DrawStripIsColorSlot(slot)) return false;
   if(c == clrNONE) return false;
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   //--- P-PAL-21: the strip's own RECENT ring went with its board (nothing paints
   //--- it any more); the cards' palette keeps the history this product shares.
   DrawStripUndoPush();
   if(slot == DRAW_SLOT_FILLCLR) DrawStripFillShowGroup();   // P-DRAW-64: a colour is a fill
   DrawStripWriteValue(slot, (double)(int)c);
   if(slot == DRAW_SLOT_COLOR) BoxMidSyncGroup();   // P-DRAW-64a: the level wears the border
   return true;
}

//--- P-DRAW-11: APPLY one picker row — through the group fan-out (P-DRAW-09b),
//--- learning the look for the next drawing of the kind (P-DRAW-01c). Placed
//--- here (after DrawStripWriteValue) because MQL4 is define-before-use.
bool DrawStripPickApply(const int slot, const int row)
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   EDrawKind k = s_dsKind;
   if(k == DK_NONE) return false;
   if(DrawStripIsColorSlot(slot))
      return DrawStripColorCommit(slot, DrawStripPickColor(slot, row));
   if(slot == DRAW_SLOT_WIDTH || slot == DRAW_SLOT_BODYWIDTH)
   {
      if(row < 0 || row > 4) return false;
      DrawStripUndoPush();
      DrawStripWriteValue(slot, (double)(row + 1));
      return true;
   }
   //--- P-DRAW-BODY-UI: native five only — never a look tag, never the levels.
   if(slot == DRAW_SLOT_BODYSTYLE)
   {
      if(row < 0 || row > 4) return false;
      DrawStripUndoPush();
      DrawStripWriteValue(DRAW_SLOT_BODYSTYLE, (double)row);
      return true;
   }
   if(slot == DRAW_SLOT_STYLE)
   {
      // P-LOOK: the count lives in DrawStripPickCount — a second bound here is
      // how the fibo's own rows 5/6/7 arrived dead (painted, never applied).
      if(row < 0 || row >= DrawStripPickCount(k, slot)) return false;
      DrawStripUndoPush();
      DrawStripWriteValue(DRAW_SLOT_STYLE, (double)row);
      return true;
   }
   if(slot == DRAW_SLOT_RAY)
   {
      if(row < 0 || row > 3) return false;
      DrawStripUndoPush();
      DrawStripWriteValue(DRAW_SLOT_RAY, (double)row);
      return true;
   }
   if(slot == DRAW_SLOT_FONT)
   {
      if(row < 0 || row >= DrawStripFontCount()) return false;
      DrawStripUndoPush();
      DrawStripWriteValue(DRAW_SLOT_FONT, (double)DrawStripFontAt(row));
      return true;
   }
   if(slot == DRAW_SLOT_GLYPH)
   {
      if(row < 0 || row >= DrawStripGlyphCount()) return false;
      DrawStripUndoPush();
      DrawStripWriteValue(DRAW_SLOT_GLYPH, (double)DrawStripGlyphAt(row));
      return true;
   }
   return false;
}

// ══════════════════════════════════════════════════════════════════════════
// P-DRAW-13 — LEVEL MEMBERSHIP WRITES (held drawing only) + DUPLICATE.
// ══════════════════════════════════════════════════════════════════════════
bool DrawStripLevelsRewrite(double &vals[], color &clrs[], int &wds[], int &sts[], string &txts[], const int n)
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   if(!DrawKindHasLevels(s_dsKind)) return false;
   if(n < 0 || n > 32) return false;
   ObjectSetInteger(0, s_dsObj, OBJPROP_LEVELS, n);
   for(int i = 0; i < n; i++)
   {
      ObjectSetDouble(0, s_dsObj, OBJPROP_LEVELVALUE, i, vals[i]);
      ObjectSetInteger(0, s_dsObj, OBJPROP_LEVELCOLOR, i, clrs[i]);
      ObjectSetInteger(0, s_dsObj, OBJPROP_LEVELWIDTH, i, wds[i]);
      ObjectSetInteger(0, s_dsObj, OBJPROP_LEVELSTYLE, i, sts[i]);
      //--- P-LVL-TEXT: texts ride index-aligned with values — a rewrite that
      //--- moved values but not texts would glue notes onto the wrong levels.
      ObjectSetString(0, s_dsObj, OBJPROP_LEVELTEXT, i, txts[i]);
   }
   FibPenTagDrop(s_dsObj);   // P-DRAW-74b: rewritten truth spends the memory
   FibPenSync(s_dsObj, false);   // P-DRAW-74b: rewritten truth converges here
   return true;
}
void DrawStripLevelsCollect(double &vals[], color &clrs[], int &wds[], int &sts[], string &txts[], int &n)
{
   n = 0;
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return;
   int cur = DrawLevelCount(s_dsObj);
   for(int i = 0; i < cur && n < 32; i++)
   {
      //--- P-LVL-SCALE: the funnel migrates old percent-stored sets (23.6) to
      //--- ratios (0.236) on the next rewrite — every toggle/add/set-all heals.
      double v = DrawStripLevelNorm(DrawLevelValue(s_dsObj, i));
      if(!MathIsValidNumber(v)) continue;
      vals[n] = v;
      clrs[n] = (color)(int)ObjectGetInteger(0, s_dsObj, OBJPROP_LEVELCOLOR, i);
      wds[n] = FibPenLogicalWidth(s_dsObj, i);   // P-DRAW-74b: collect the remembered width, not the thinned one
      sts[n] = (int)ObjectGetInteger(0, s_dsObj, OBJPROP_LEVELSTYLE, i);
      txts[n] = ObjectGetString(0, s_dsObj, OBJPROP_LEVELTEXT, i);
      n++;
   }
}
//--- toggle one membership value (multi-stay: the editor does NOT close).
bool DrawStripLevelsToggle(const double v)
{
   //--- P-LVL-SCALE: the value rides normalized (ratio) — collected rows already
   //--- are, so a percent-typed 88.6 meets the stored 0.886 instead of doubling it.
   double nv = DrawStripLevelNorm(v);
   if(!MathIsValidNumber(nv)) return false;
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   DrawStripUndoPush();
   double vals[32]; color clrs[32]; int wds[32]; int sts[32]; string txts[32]; int n = 0;
   DrawStripLevelsCollect(vals, clrs, wds, sts, txts, n);
   int at = -1;
   for(int i = 0; i < n; i++)
      if(MathAbs(vals[i] - nv) < 0.000001) { at = i; break; }
   if(at >= 0)
   {
      for(int j = at; j < n - 1; j++)
      { vals[j] = vals[j + 1]; clrs[j] = clrs[j + 1]; wds[j] = wds[j + 1]; sts[j] = sts[j + 1]; txts[j] = txts[j + 1]; }
      n--;
   }
   else
   {
      if(n >= 32) return false;
      vals[n] = nv;
      clrs[n] = (color)(int)DrawSlotRead(s_dsObj, DRAW_SLOT_COLOR);
      wds[n] = (int)DrawSlotRead(s_dsObj, DRAW_SLOT_WIDTH);
      sts[n] = (int)DrawSlotRead(s_dsObj, DRAW_SLOT_STYLE);
      txts[n] = "";
      n++;
   }
   return DrawStripLevelsRewrite(vals, clrs, wds, sts, txts, n);
}
//--- All / None for the common nine.
bool DrawStripLevelsSetAll(const bool on)
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   if(!DrawKindHasLevels(s_dsKind)) return false;
   DrawStripUndoPush();
   if(!on)
   {
      double vals[32]; color clrs[32]; int wds[32]; int sts[32]; string txts[32];
      int n = 0;
      return DrawStripLevelsRewrite(vals, clrs, wds, sts, txts, n);
   }
   //--- P-LVL-KEEP: "All levels on" is a UNION — the hand's customs (0.3, 88.6)
   //--- keep their own rows and colors; only the missing commons are appended in
   //--- the slot's look. The old shape rewrote the nine commons alone and silently
   //--- dropped every custom the user had added.
   double vals[32]; color clrs[32]; int wds[32]; int sts[32]; string txts[32]; int n = 0;
   DrawStripLevelsCollect(vals, clrs, wds, sts, txts, n);
   color c = (color)(int)DrawSlotRead(s_dsObj, DRAW_SLOT_COLOR);
   int w = (int)DrawSlotRead(s_dsObj, DRAW_SLOT_WIDTH);
   int st = (int)DrawSlotRead(s_dsObj, DRAW_SLOT_STYLE);
   for(int i = 0; i < DrawStripLevelCommonCount() && n < 32; i++)
   {
      double cv = DrawStripLevelCommon(i);
      bool has = false;
      for(int j = 0; j < n; j++)
         if(MathAbs(vals[j] - cv) < 0.000001) { has = true; break; }
      if(has) continue;
      vals[n] = cv; clrs[n] = c; wds[n] = w; sts[n] = st; txts[n] = "";
      n++;
   }
   return DrawStripLevelsRewrite(vals, clrs, wds, sts, txts, n);
}
//--- DUPLICATE: a true clone beside itself (anchors + look + levels), the copy
//--- selected and served. Time anchors step one chart bar so the two do not sit
//--- exactly atop each other. Undoable (the copy is deleted).
bool DrawStripDuplicate()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   int type = DrawObjectType(s_dsObj);
   if(type < 0) return false;
   DrawStripUndoPush();
   string base = s_dsObj + "_c";
   string nm = base;
   for(int i = 2; i < 100; i++)
   {
      if(ObjectFind(0, nm) < 0) break;
      nm = base + IntegerToString(i);
   }
   if(ObjectFind(0, nm) >= 0) return false;
   datetime t0 = (datetime)ObjectGetInteger(0, s_dsObj, OBJPROP_TIME, 0);
   double p0 = ObjectGetDouble(0, s_dsObj, OBJPROP_PRICE, 0);
   if(t0 <= 0 || !(p0 > 0.0)) return false;
   if(!ObjectCreate(0, nm, (ENUM_OBJECT)type, 0, t0, p0)) return false;
   long step = (long)Period() * 60;
   if(step <= 0) step = 60;
   for(int a = 0; a < 3; a++)
   {
      datetime t = (datetime)ObjectGetInteger(0, s_dsObj, OBJPROP_TIME, a);
      double p = ObjectGetDouble(0, s_dsObj, OBJPROP_PRICE, a);
      if(t > 0) ObjectSetInteger(0, nm, OBJPROP_TIME, a, t + step);
      if(p > 0.0) ObjectSetDouble(0, nm, OBJPROP_PRICE, a, p);
   }
   ObjectSetInteger(0, nm, OBJPROP_COLOR, ObjectGetInteger(0, s_dsObj, OBJPROP_COLOR));
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, ObjectGetInteger(0, s_dsObj, OBJPROP_WIDTH));
   ObjectSetInteger(0, nm, OBJPROP_STYLE, ObjectGetInteger(0, s_dsObj, OBJPROP_STYLE));
   ObjectSetInteger(0, nm, OBJPROP_FILL, ObjectGetInteger(0, s_dsObj, OBJPROP_FILL));
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, ObjectGetInteger(0, s_dsObj, OBJPROP_RAY_RIGHT));
   ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT, ObjectGetInteger(0, s_dsObj, OBJPROP_RAY_LEFT));
   ObjectSetInteger(0, nm, OBJPROP_BACK, ObjectGetInteger(0, s_dsObj, OBJPROP_BACK));
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTED, false);
   if(DrawKindOf(nm) == DK_TEXT)
   {
      ObjectSetString(0, nm, OBJPROP_TEXT, ObjectGetString(0, s_dsObj, OBJPROP_TEXT));
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, ObjectGetInteger(0, s_dsObj, OBJPROP_FONTSIZE));
      ObjectSetString(0, nm, OBJPROP_FONT, ObjectGetString(0, s_dsObj, OBJPROP_FONT));
   }
   if(DrawKindOf(nm) == DK_ARROW)
      ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, ObjectGetInteger(0, s_dsObj, OBJPROP_ARROWCODE));
   ObjectSetString(0, nm, OBJPROP_TEXT,
                   ObjectGetString(0, s_dsObj, OBJPROP_TEXT));
   // P-DRAW-23: a copy starts CLEAN. The description carries the box extras
   // markers, and inheriting them would arm mid + extend on a box the user
   // never asked for (a duplicate that runs away on the next bar).
   if(DrawKindOf(nm) == DK_RECT) BoxMarkWrite(nm, false, BOXEXT_OFF, 0);
   if(DrawKindHasLevels(s_dsKind))
   {
      double vals[32]; color clrs[32]; int wds[32]; int sts[32]; string txts[32]; int n = 0;
      DrawStripLevelsCollect(vals, clrs, wds, sts, txts, n);
      ObjectSetInteger(0, nm, OBJPROP_LEVELS, n);
      for(int l = 0; l < n; l++)
      {
         ObjectSetDouble(0, nm, OBJPROP_LEVELVALUE, l, vals[l]);
         ObjectSetInteger(0, nm, OBJPROP_LEVELCOLOR, l, clrs[l]);
         ObjectSetInteger(0, nm, OBJPROP_LEVELWIDTH, l, wds[l]);
         ObjectSetInteger(0, nm, OBJPROP_LEVELSTYLE, l, sts[l]);
         //--- P-LVL-TEXT: the collected note rides its own value (source indices
         //--- shift past invalid rows, so re-reading by index would mis-glue them).
         ObjectSetString(0, nm, OBJPROP_LEVELTEXT, l, txts[l]);
      }
      FibPenSync(nm, false);   // P-DRAW-74b: the copy converges beside the copy
   }
   s_duCopy = nm;
   ObjectSetInteger(0, nm, OBJPROP_SELECTED, true);
   DrawStripOpen(nm);
   ChartRedraw();
   return true;
}

//--- P-DRAW-13 — A TAP OPENS, IT NEVER GUESSES. Quick value cells toggle their
//--- popover (BaseKnot's dropdown contract); toggles flip at once; chrome
//--- actions fire at once. No branch here mutates a value off a value cell.
//--- P-DRAW-64a: `tap` names the OBJECT the terminal reported, because the merged
//--- colour seat carries two roles and the hand's own landing decides which one:
//--- the centred swatch and its skin are the INTERIOR's, the cell's button and its
//--- 32px skin the BORDER's.
bool DrawStripTap(const int idx, const string tap)
{
   if(!s_dsOpen || s_dsObj == "" || idx < 0 || idx >= DSTRIP_MAX_SLOTS) return false;
   if(idx >= s_dsN) return false;
   EDrawKind k = s_dsKind;
   if(k == DK_NONE) { DrawStripClose(); return true; }
   int slot = DrawStripQuickSlotAt(k, idx);
   if(slot < 0) return true;
   if(slot == DRAW_SLOT_FILLCLR)
   {
      string seat = DrawStripIconName(idx);
      if(tap != seat + "S" && tap != seat + "C2") slot = DRAW_SLOT_COLOR;
   }
   //--- P-PAL-19 (2026-10-02) — A COLOUR CELL DOES NOT OPEN A BOARD. The strip used
   //--- to paint its own palette here (a second one, with its own catalogue, recents
   //--- and hex field) while every card opened `PalOpenKind`. It does not any more:
   //--- the tap leaves a REQUEST and the entry's bridge opens the cards' palette on
   //--- this drawing, so there is ONE palette in the product. The board code and its
   //--- objects go with the next step of the migration; until then the request is the
   //--- only thing this branch does, which is why it is the FIRST branch — a colour
   //--- slot must never reach the `HasPicker` grid below.
   if(DrawStripIsColorSlot(slot))
   {
      DrawStripPalAsk(slot);
      return true;
   }
   if(DrawStripHasPicker(slot))
   {
      DrawStripGearClose();
      if(s_dsPicker == slot) DrawStripClosePicker();
      else s_dsPicker = slot;
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   if(DrawStripIsToggle(slot))
   {
      DrawStripUndoPush();
      double tv = (DrawSlotRead(s_dsObj, slot) > 0.5) ? 0.0 : 1.0;
      DrawStripWriteValue(slot, tv);
      //--- DIAG-131 (2026-10-02): the tap names itself, the slot, and the value the
      //--- OBJECT now holds — and it goes through the FLUSHED channel
      //--- (`DrawStripDiagEmit`), not `Print`: MEASURED 2026-10-02, the Experts
      //--- journal stood at 08:47:07 for seven minutes while the user's clicks went
      //--- into MT4's RAM buffer (P-DRAW-126's own finding), so a witness written
      //--- with `Print` answers «nothing happened» long after the tap happened. The
      //--- layers/BACK cell was reported as «کارش درست انجام نمیشه» with nothing to
      //--- confirm or refute it, so the line carries the ONE fact that settles it:
      //--- the FILL slot's read-back beside the tapped slot's, plus whether the
      //--- interior child exists — a tap that moved the layer never touches either.
      DrawStripDiagEmit("[drawstrip] SLOT slot=" + IntegerToString(slot) +
                        " name=" + DrawStripSwitchName(s_dsObj, slot) +
                        " obj=\"" + s_dsObj + "\" -> " + DoubleToString(tv, 0) +
                        " read=" + DoubleToString(DrawSlotRead(s_dsObj, slot), 0) +
                        " fill=" + DoubleToString(DrawSlotRead(s_dsObj, DRAW_SLOT_FILL), 0) +
                        " child=" + IntegerToString(ObjectFind(0, FillChildName(s_dsObj)) >= 0) +
                        //--- DIAG-133: the DESCRIPTION ITSELF, quoted. P-UI-133 was fixed
                        //--- against a model of this string and the live box disagreed with
                        //--- the model (both marks still refused to clear), so the witness
                        //--- now carries the bytes the surgery runs on. One read, on the tap
                        //--- path only — the cost that matters is per-frame, and a tap is not
                        //--- a frame.
                        " desc=\"" + ObjectGetString(0, s_dsObj, OBJPROP_TEXT) + "\"");
      // P-DRAW-09b: locking is the one tap that can end the group's usefulness
      // (a locked member cannot be grabbed again by accident), so the strip
      // loses nothing here — it stays, and one more tap frees it.
      DrawStripPaint();
      //--- P-DRAW-64a: the WHOLE group, not just the held box — a BACK flip moves every
      //--- member's layer, and every member wearing its level needs the new one. One
      //--- description read per member per tap (a tap is not a stream), writes only
      //--- where something really changed.
      BoxMidSyncGroup();   // P-DRAW-21: a fill/lock/back flip restyles the mid
      //--- P-DRAW-64c: ...and a tap that SWITCHED THE TRAVEL ON takes the first step
      //--- itself, so the edge moves in this frame instead of on the next bar.
      //--- P-UI-132 (2026-10-02): and the ORDER is the fix. The edge the hand drew is
      //--- remembered BEFORE the first step moves it, and the tap that switches the
      //--- travel OFF gives it back — «اکستند خاموش میکنم بر نمیگرده به حالت اول» is one
      //--- missing restore, and the 50 % line riding the stretched edge («50 درصد …
      //--- خاموش و روشن نمیشه چرا تداخل داره») stops riding the moment the edge is
      //--- given back. Both halves are the same two numbers, so the cost is one memo
      //--- write at the arming and one at the disarming, and nothing at all per frame.
      if(slot == DRAW_SLOT_EXTEND)
      {
         if(tv > 0.5) { BoxEdgeRememberGroup(); BoxExtendStepGroup(); }
         else          { BoxEdgeRestoreGroup(); }
      }
      //--- P-UI-131 (2026-10-02): P-DRAW-127's own law — «A user action gets one
      //--- unconditional flush; a paint pass never does» — was carried by the GEAR
      //--- branch below and missing HERE, on the branch that flips a cell's whole
      //--- face (the BACK/layers glyph is 15px art in a 26px seat, so its two states
      //--- also swap art, not only a chip). `DrawStripPaint` flushes only
      //--- `if(dirty)`, and the measured failure of relying on that (P-DRAW-127) is
      //--- «the object LIST is right and the PIXELS are one frame behind» — a cell
      //--- that reports the new state while the chart still shows the old one, which
      //--- to the user is a tap that did not happen. One flush, here, ends that.
      ChartRedraw();
      return true;

   }

   return true;
}
//--- chrome: more / gear / pin / del.
bool DrawStripActTap(const int a)
{
   if(!s_dsOpen || s_dsObj == "") return false;
   if(a == DSTRIP_ACT_MORE)
   {
      DrawStripGearClose();
      if(s_dsPicker == DSTRIP_MORE) DrawStripClosePicker();
      else s_dsPicker = DSTRIP_MORE;
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
    if(a == DSTRIP_ACT_GEAR)
    {
       DrawStripClosePicker();
       if(s_dsGear != 0) DrawStripGearClose();
       //--- P-DRAW-65: the colours open first. P-DRAW-117: and a fresh open shows
       //--- that group's SETTINGS — the panel never opens folded.
       else { s_dsGear = DSTRIP_GEAR_PAINT; s_dsGearCollapsed = false; }
       //--- P-DRAW-86 (2026-09-29): THE OPEN SWEEPS FIRST. The close-purge kills
       //--- every PnlDrawS_G* — but only if the close ran. A terminal restart, a
       //--- crash, or a build that predates the purge leaves same-prefix objects
       //--- on the chart, and the new paint repaints same-name ones but never
       //--- deletes a stale bed (the blue GTrack that survived three re-adds).
       //--- One bounded pass on open, never on paint.
      DrawStripGearObjectsPurge();
      DrawStripLayout();
      DrawStripPaint();
       //--- P-DRAW-123: the dump, not the bare census — one armed repaint prints the
       //--- `[dsdiag] EXPECT` half of what the terminal is about to answer with.
       DrawStripGearDiagDump();   // P-DRAW-87/112/123: the panel names its objects
       //--- P-DRAW-127 (2026-10-01) — A PANEL OPEN FLUSHES ITS OWN FRAME.
       //--- MEASURED on the 22:10/22:13 frames of
       //--- `biotak_diag_EURUSD_134342075006101685.txt`: the WIDE (624px) open declared
       //--- all 91 objects correct and unoccluded while the SCREEN showed its left
       //--- column empty — the object LIST was right and the PIXELS were one frame
       //--- behind. `DrawStripPaint` flushes with `if(dirty) ChartRedraw()` (its own
       //--- line), and the dump's repaint above (P-DRAW-125a) DISCARDS its return, so a
       //--- panel whose geometry moved without any write reporting dirty kept the
       //--- previous frame — and a second click "fixed" it because that one did write.
       //--- A user action gets one unconditional flush; a paint pass never does.
       ChartRedraw();
       return true;
    }
   if(a == DSTRIP_ACT_PIN)
   {
      //--- P-UI-131: the pin's ONE line of code, and the one flush P-DRAW-127 asks
      //--- every user action for — the GEAR branch below has carried it since that
      //--- measurement, the pin never did. A toggle whose only visible proof is a
      //--- chip colour and a glyph swap is exactly the case the law names, so the
      //--- tap now says WHICH way it went (DIAG-131) as well as flushing.
      s_dsPinned = !s_dsPinned;
      DrawStripDiagEmit("[drawstrip] PIN " + (s_dsPinned ? "pinned" : "unpinned") +
                        " obj=\"" + s_dsObj + "\"");
      DrawStripPaint();
      ChartRedraw();
      return true;
   }
   if(a == DSTRIP_ACT_DIR)
   {
      //--- P-BK-111: THE CELL IS A CALL ON THE KNOT LAYER, so the call and the rebuild
      //--- are the same branch: the side is a published fact (the marker, the note's
      //--- caption, the family's colours), so a flip that does not repaint is a flip the
      //--- user cannot see. `BaseKnotSync` is the family's own owner for that reason.
      DrawStripClosePicker();
      string id = BaseKnotDirBoxFor(s_dsObj);
      if(id != "" && BaseKnotFlipDirection(id))
      {
         BaseKnotSync(id);
         DrawStripLayout();
         DrawStripPaint();
         ChartRedraw();   // P-DRAW-127: a user action flushes its own frame
      }
      //--- NOT A BASE BOX: the cell consumed the click and changed nothing, on purpose.
      //--- A refused action must not fall through to a neighbour's tap, and it must not
      //--- repaint either - there is nothing new on the chart to show.
      return true;
   }
   if(a == DSTRIP_ACT_DEL) { DrawStripFireDelete(); return true; }
   return true;
}
//--- group delete from the strip (P-DRAW-08d). Not undoable: MT4 has no undelete.
void DrawStripFireDelete()
{
   if(!s_dsOpen) return;
   DrawSelPrune();
   int n = DrawSelCount();
   // P-DRAW-21: a box delete takes its mid child (else an orphan trend survives).
   //--- P-DRAW-64: and its interior. A child MT4 never cascades: leaving it behind
   //--- would be a filled shape with no drawing around it.
   if(n > 0)
   {
      for(int j = 0; j < n; j++)
      {
         if(DrawIsHRay(DrawSelAt(j))) { HRayDelete(DrawSelAt(j), "strip bin"); continue; }   // P-HR-04: dot goes with the line
         // P-UI-136: a segment in the bin takes its WHOLE path with it — one drawing,
         // one sweep. `continue` because the generic branch would delete the segment
         // alone and leave the rest of the polyline on the chart.
         if(DrawIsPathSeg(DrawSelAt(j))) { string tmpId = ""; if(PathIdOfName(DrawSelAt(j), tmpId)) PathDelete(tmpId, "strip bin"); continue; }
         BoxEdgeForget(DrawSelAt(j));   // P-UI-132: a deleted box spends its edge memo here, not by expiry
         BoxMarkDrop(DrawSelAt(j));   // P-UI-134: ...and so does its marks KEY
         FibPenSync(DrawSelAt(j), true);   // P-DRAW-74b: strays and the tag die with the object
         BoxMidDrop(DrawSelAt(j)); FillChildDrop(DrawSelAt(j)); ObjectDelete(0, DrawSelAt(j));
      }
   }
   else if(s_dsObj != "")
   {
      if(DrawIsHRay(s_dsObj)) HRayDelete(s_dsObj, "strip bin");   // P-HR-04
      // P-UI-136: and the single held object is a segment — the whole path goes.
      else if(DrawIsPathSeg(s_dsObj)) { string tmpId = ""; if(PathIdOfName(s_dsObj, tmpId)) PathDelete(tmpId, "strip bin"); }
      else { BoxEdgeForget(s_dsObj); BoxMarkDrop(s_dsObj); FibPenSync(s_dsObj, true); BoxMidDrop(s_dsObj); FillChildDrop(s_dsObj); ObjectDelete(0, s_dsObj); }
   }
   DrawStripClose();
   ChartRedraw();
}
//--- P-DRAW-11 — A PICK APPLIES AND SHUTS (levels, and the colour board since
//--- P-DRAW-48: multi-stay). The caller passes the popover row; the row is
//--- validated against the open popover's own count.
bool DrawStripPickTap(const int row)
{
   if(!s_dsOpen || s_dsObj == "") return false;
   if(s_dsPicker == DSTRIP_PICK_NONE) return false;
   //--- P-DRAW-64: the scrub's release witness, asked FIRST — whichever channel gets
   //--- here first applies; the second only clears the highlight.
   if(s_dsPalDoneMs != 0 && GetTickCount() - s_dsPalDoneMs < DSTRIP_PAL_TAIL_MS)
      return DrawStripClickFamily();
   if(s_dsPalGrab) { s_dsPalDoneMs = GetTickCount(); DrawStripPalHighlightEnd(); }
   if(DrawStripIsColorSlot(s_dsPicker)) DrawStripColorHoverClear();
   if(row < 0 || row >= s_dsPN) return false;
   if(s_dsPicker == DSTRIP_MORE) return DrawStripMoreTap(row);
   if(s_dsPicker == DSTRIP_SLOT_LEVELS)
   {
      double v = DrawStripGearLevelAt(row);
      if(!MathIsValidNumber(v)) return false;
      DrawStripLevelsToggle(v);
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   DrawStripPickApply(s_dsPicker, row);
   // DIAG-137 (2026-10-03) — EVERY tap leaves its number: slot, row, object and
   // the read-back. A control that paints but never writes («هرچی ضخیم تر
   // انتخاب میکنم تاثییری نداره») is otherwise indistinguishable from a paint
   // that ignores the write. The tap IS the event, so there is no dirty-only.
   if(s_dsPicker != DSTRIP_MORE && s_dsPicker != DSTRIP_SLOT_LEVELS)
   {
      // DIAG-138 (2026-10-03) — the tag ITSELF joins the line: lk/gi parsed value
      // beside haslk/raw search tells a failed drop (haslk=1) from a misread.
      string ptxt = ObjectGetString(0, s_dsObj, OBJPROP_TEXT);
      int plk = FibPenLookGet(s_dsObj);
      DrawStripDiagEmit("[drawstrip] PICK slot=" + IntegerToString(s_dsPicker) +
                        " row=" + IntegerToString(row) + " obj=\"" + s_dsObj +
                        "\" read=" + DoubleToString(DrawSlotRead(s_dsObj, s_dsPicker), 0) +
                        " lk=" + IntegerToString(plk) +
                        " haslk=" + (StringFind(ptxt, FIBPEN_LK) >= 0 ? "1" : "0"));
   }
   //--- P-DRAW-48 — THE COLOUR BOARD STAYS. User order: «روی رنگ کلیک میکنم بسته
   //--- میشه نمیزاره شفافیت تنظیم بکنم» — the board carries the opacity bar, so a
   //--- pick that shuts it takes the bar away exactly when the next act is tuning
   //--- it. The value applies; ✕, Esc or the strip's colour cell close the board.
   if(DrawStripIsColorSlot(s_dsPicker)) { DrawStripPaint(); return true; }
   DrawStripClosePicker();
   DrawStripLayout();
   DrawStripPaint();
   return true;
}
//--- P-DRAW-64 — THE 50% FILL's write: the group fan-out, undoable, through the
//--- one owner of the FILL slot and the one owner of the tone (`DrawStripFill50On`
//--- above). It lives here because the undo push and the group are defined here.
bool DrawStripFill50Apply()
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   if(!DrawSlotAvailable(s_dsKind, DRAW_SLOT_FILLCLR)) return false;
   DrawStripUndoPush();
   DrawSelPrune();
   int n = DrawSelCount();
   if(n <= 0) { DrawStripFill50On(s_dsObj); return true; }
   for(int i = 0; i < n; i++) DrawStripFill50On(DrawSelAt(i));
   return true;
}

//--- more-popover rows.
bool DrawStripMoreTap(const int row)
{
   if(row < 0 || row >= s_dsPN) return false;
   int kind = s_dsMoreKind[row], arg = s_dsMoreArg[row];
   if(kind == DSTRIP_MK_APPLYALL)
   {
      // THE CONTROL MT4 DOES NOT HAVE: this look, on every drawing of this tool.
      DrawStyleApplyToKind(s_dsObj);
      DrawStripClosePicker();
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   if(kind == DSTRIP_MK_PRESET)
   {
      DrawStripPresetApplyGroup(arg);
      DrawStripClosePicker();
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   if(kind == DSTRIP_MK_SAVE)
   {
      // P-DRAW-25: the more-menu save arms the same name edit (one seat, in
      // the Template tab) instead of an anonymous "My N".
      s_dsTplNameArmed = true;
      DrawStripClosePicker();
      s_dsGear = DSTRIP_GEAR_TPL;
      if(s_dsKind > DK_NONE && s_dsKind < DK_COUNT) s_dsGearMem[s_dsKind] = s_dsGear;
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   if(kind == DSTRIP_MK_DUPE) return DrawStripDuplicate();
   if(kind == DSTRIP_MK_BOX50)
   {
      bool mid = false; int ext = BOXEXT_OFF, n = 0;
      BoxMarkRead(s_dsObj, mid, ext, n);
      //--- DIAG-134: the 50 % row reads the mark, flips it, and answers with the mark
      //--- AFTER the write plus whether the line object exists — the exact fact that
      //--- failed three times over («50 درصد … چرا تداخل داره»), now settled by one read.
      BoxMarkWrite(s_dsObj, !mid, ext, n);
      BoxMidSync(s_dsObj);
      bool am = false; int ae = BOXEXT_OFF, an = 0;
      BoxMarkRead(s_dsObj, am, ae, an);
      DrawStripDiagEmit("[drawstrip] BOX50 name=\"" + s_dsObj + "\" " +
                        (mid ? "on->off" : "off->on") + " read=" +
                        DoubleToString((am ? 1.0 : 0.0), 0) + " line=" +
                        IntegerToString(ObjectFind(0, BoxMidName(s_dsObj)) >= 0) +
                        " ext=" + IntegerToString(ae));
      DrawStripClosePicker();
      DrawStripLayout();
      DrawStripPaint();
      ChartRedraw();   // P-UI-131: the 50 % is the cell the user watches for its own frame
      return true;
   }
   if(kind == DSTRIP_MK_BOXEXT)
   {
      //--- DIAG-134 (2026-10-02) — THE OTHER TWO DOORS ANSWER TOO. DIAG-131 witnessed the
      //--- quick cell, and it is what finally closed the 50 % / EXTEND report — but the
      //--- cycle and the gear switch were fixed on the SAME DAY with NO witness, which is
      //--- exactly how a fix can be wrong and still look green. A witness is cheap on a
      //--- tap (the cost that matters is per-frame) and it is the only thing that makes
      //--- the NEXT report answerable without a reproduction round-trip. Read BEFORE, so
      //--- the line names the mode it walked FROM as well as the one it landed on, and
      //--- the memo slot, so «extend off did not come back» is settled by the memo.
      bool bmid = false; int bext = BOXEXT_OFF, bn = 0;
      BoxMarkRead(s_dsObj, bmid, bext, bn);
      string was = BoxExtText(s_dsObj);
      BoxExtCycle(s_dsObj);
      //--- P-DRAW-64c: the cycle may have armed TOUCH/END/NBARS — the first step is
      //--- still the tap's, so the edge moves in this frame even when the next bar is
      //--- an hour away. A cycle that landed on OFF is a no-op here by construction.
      BoxExtendStep(s_dsObj);
      DrawStripDiagEmit("[drawstrip] BOXEXT name=\"" + s_dsObj + "\" from=\"" + was +
                        "\" to=\"" + BoxExtText(s_dsObj) + "\" memo=" +
                        IntegerToString(BoxEdgeSlot(s_dsObj)));
      DrawStripClosePicker();
      DrawStripLayout();
      DrawStripPaint();
      ChartRedraw();   // P-UI-131: ...and the edge it just moved is the visible half
      return true;
   }
   if(kind == DSTRIP_MK_FILL50)
   {
      DrawStripFill50Apply();
      DrawStripPaint();
      return true;   // the row's own state changed: the popover stays where it is
   }
   if(kind == DSTRIP_MK_UNDO)
   {
      if(!s_duValid) return true;
      DrawStripUndoPop();
      DrawStripClosePicker();
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   if(kind == DSTRIP_MK_SLOT)
   {
      s_dsPicker = arg;   // overflow value slot: its grid replaces more
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   return true;
}
//--- gear grid cells: swatches (P-DRAW-118), the two openers, and the chips.
bool DrawStripGridTap(const int g)
{
   if(!s_dsOpen || s_dsObj == "") return false;
   if(g < 0 || g >= s_dsGGN) return false;
   DrawStripColorHoverClear();
   int gk = s_dsGGKind[g], slot = s_dsGGSlot[g];
   //--- P-DRAW-118: a swatch APPLIES THE COLOUR IT WEARS — read from `s_dsGGC`, the
   //--- array the paint wrote (Touch rule 7: a hit test with its own arithmetic is a
   //--- second grid) — through the colour's one owner.
   if(gk == DSTRIP_GRG_SWATCH)
   {
      if(!DrawStripColorCommit(slot, s_dsGGC[g])) return false;
      DrawStripPaint();
      BoxMidSyncServed();   // P-DRAW-21: a grid restyle restyles the mid
      return true;
   }
   //--- the preview block and the `+` are the SAME act: the palette on this role. The
   //--- strip keeps ONE picker at a time (DrawStripTap does exactly this for a
   //--- quick-row colour cell), so the panel steps aside for the popup it opens — and
   //--- P-PAL-19: for a COLOUR role that popup is the CARDS' palette, through the same
   //--- request/bridge as the quick cell. Two doors, one act, one palette.
   if(gk == DSTRIP_GRG_PREV || gk == DSTRIP_GRG_PLUS)
   {
      DrawStripGearClose();
      if(DrawStripIsColorSlot(slot))
      {
         DrawStripPalAsk(slot);
         return true;
      }
      if(s_dsPicker == slot) DrawStripClosePicker();
      else s_dsPicker = slot;
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   DrawStripPickApply(slot, s_dsGGArg[g]);   // P-DRAW-44: chips
   DrawStripPaint();
   BoxMidSyncServed();   // P-DRAW-21: a grid restyle restyles the mid
   return true;
}
//--- gear list rows.
bool DrawStripGearRowTap(const int r)
{
   if(!s_dsOpen || s_dsObj == "") return false;
   if(r < 0 || r >= s_dsGRN) return false;
   int kind = s_dsGRKind[r], arg = s_dsGRArg[r];
   //--- P-DRAW-117: a group header opens (or folds) its own group. The row probe
   //--- reaches this the same way it reaches a switch — one hit test, no second grid
   //--- (P-DRAW-84's own law: the hit test reads the seat arrays the paint wrote).
   if(kind == DSTRIP_GRK_GROUP) return DrawStripGearGroupTap(arg);
   if(kind == 1)
   {
      DrawStripUndoPush();
      double tv = (DrawSlotRead(s_dsObj, arg) > 0.5) ? 0.0 : 1.0;
      DrawStripWriteValue(arg, tv);
      DrawStripPaint();
      BoxMidSyncServed();   // P-DRAW-21: a gear toggle restyles the mid
      //--- P-DRAW-64c: the gear's switch takes the first travel step too — same frame,
      //--- same rule as the quick cell above.
      //--- P-UI-132 addendum: and it is the SAME cell, so it carries the same memo. This
      //--- row armed the mode and moved the edge with no memo written, and its disarm
      //--- half had nothing to restore from — the strip row was fixed and the gear row
      //--- left holding the defect, which is how a fix reads as «sometimes works». One
      //--- remember, one restore, both group fan-outs (the group here is the whole
      //--- multi-selection, exactly as above).
      if(arg == DRAW_SLOT_EXTEND)
      {
         if(tv > 0.5) { BoxEdgeRememberGroup(); BoxExtendStepGroup(); }
         else          { BoxEdgeRestoreGroup(); }
      }
      //--- DIAG-134: the gear switch is the same cell as the quick one and it gets the
      //--- same witness, for the same reason — it is one of the three doors into EXTEND,
      //--- and it is the door a report names least often while being the one a fix is
      //--- most likely to have missed. The memo slot is the fact that settles «the box
      //--- never came back»: armed must leave a memo, a disarm must leave none.
      if(arg == DRAW_SLOT_EXTEND)
         DrawStripDiagEmit("[drawstrip] GEAREXT name=\"" + s_dsObj + "\" -> " +
                           DoubleToString(tv, 0) + " read=" +
                           DoubleToString(DrawSlotRead(s_dsObj, arg), 0) + " memo=" +
                           IntegerToString(BoxEdgeSlot(s_dsObj)));
      ChartRedraw();   // P-UI-131: a user action flushes its own frame
      return true;
   }

   if(kind == 2)
   {
      DrawStripPresetApplyGroup(arg);
      DrawStripPaint();
      return true;
   }
   if(kind == 3)
   {
      // P-DRAW-25: save ARMS the name edit («نام تمپلت‌ها رو خودمون بتونیم
      // بذاریم») — the file is still written once, on Enter (P-DRAW-08b).
      s_dsTplNameArmed = true;
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   if(kind == 4)
   {
      double v = DrawStripGearLevelAt(arg);
      if(!MathIsValidNumber(v)) return false;
      DrawStripLevelsToggle(v);
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   return true;
   if(kind == 5)
   {
      if(arg == 2)
      {
         for(int s = 0; s < DRAW_SLOT_N; s++) s_dsVis[s_dsKind][s] = true;
      }
      else DrawStripLevelsSetAll(arg == 0);
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   if(kind == 6)
   {
      int seat = (arg == DRAW_SLOT_MORE) ? DRAW_SLOT_MORE : arg;
      DrawStripVisInit();
      s_dsVis[s_dsKind][seat] = !s_dsVis[s_dsKind][seat];
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   if(kind == 7)
   {
      DrawStripLearnCurrent();
      DrawStripPaint();
      return true;
   }
   if(kind == 8)
   {
      DrawStripUndoPush();
      DrawStripWriteValue(DRAW_SLOT_GLYPH, (double)DrawStripGlyphAt(arg % 256));
      DrawStripPaint();
      return true;
   }
   return true;
}
//--- P-LVL-COLOR — ONE LEVEL'S SWATCH. The row's chip shows the ink that level
//--- wears; tapping it opens the cards palette on that STORED level (same popup
//--- as every color cell, P-PAL-19). A row whose level is not on the chart has
//--- no ink to edit, so its swatch is the same act as the row: add it.
bool DrawStripGearLevelColorTap(const int r)
{
   if(!s_dsOpen || s_dsObj == "") return false;
   if(r < 0 || r >= s_dsGRN) return false;
   if(s_dsGRKind[r] != 4) return DrawStripGearRowTap(r);
   if(!DrawKindHasLevels(s_dsKind)) return false;
   double v = DrawStripGearLevelAt(s_dsGRArg[r]);
   if(!MathIsValidNumber(v)) return false;
   int idx = DrawStripLevelFind(s_dsObj, v);
   if(idx < 0)
   {
      DrawStripLevelsToggle(v);
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   DrawStripDiagEmit("[drawstrip] LVLCOLOR obj=\"" + s_dsObj + "\" level=" +
                     IntegerToString(idx) + " v=" + DrawStripLevelName(v));
   DrawStripPalAskLevel(DRAW_SLOT_COLOR, idx);
   return true;
}
//--- P-LVL-TEXT — ONE LEVEL'S LABEL ZONE. Arms the e4 note field on that STORED
//--- level, seeded with what it wears; a re-arm on another row drops the field
//--- so it is reborn with the new seed instead of keeping the old row's word.
//--- A row whose level is not on the chart has nothing to note: same as toggle.
bool DrawStripGearLevelDescTap(const int r)
{
   if(!s_dsOpen || s_dsObj == "") return false;
   if(r < 0 || r >= s_dsGRN || s_dsGRKind[r] != 4) return DrawStripGearRowTap(r);
   if(!DrawKindHasLevels(s_dsKind)) return false;
   double v = DrawStripGearLevelAt(s_dsGRArg[r]);
   if(!MathIsValidNumber(v)) return false;
   int idx = DrawStripLevelFind(s_dsObj, v);
   if(idx < 0)
   {
      DrawStripLevelsToggle(v);
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   if(s_dsLvlDescArmed && (s_dsLvlDescObj != s_dsObj || s_dsLvlDescIdx != idx))
      ObjectDelete(0, DrawStripEditName(4));
   s_dsLvlDescArmed = true; s_dsLvlDescObj = s_dsObj; s_dsLvlDescIdx = idx;
   DrawStripDiagEmit("[drawstrip] LVLDESC obj=\"" + s_dsObj + "\" level=" +
                     IntegerToString(idx) + " v=" + DrawStripLevelName(v));
   DrawStripLayout();
   DrawStripPaint();
   if(ObjectFind(0, DrawStripEditName(4)) >= 0)
      ObjectSetInteger(0, DrawStripEditName(4), OBJPROP_STATE, true);
   return true;
}
//--- gear foot: Reset / All / Copy. P-DRAW-78: `Del` is retired from the panel —
//--- the strip's own command group already carries a trash cell, so this was a
//--- second, unconfirmed way to destroy the drawing. The head's X is the close.
//--- P-DRAW-90 (2026-09-30): `Reset` is the design's own first command (the third
//--- seat the panel was missing) — it puts THIS drawing back on its kind's factory
//--- look, i.e. the kind's own built-in preset 0 (`DrawPresetApply`, Toolbar_B:
//--- slots 0..DRAW_PRESET_BUILTIN-1 are the shipped looks), and it is UNDOABLE
//--- like every other look change (DrawStripUndoPush, the same single-step undo the
//--- more-popover's template rows push). `All` keeps its own action, one seat right;
//--- `Copy` is the third. One action per seat, and the seat's glyph now matches it.
bool DrawStripFootTap(const int f)
{
   if(!s_dsOpen || s_dsObj == "") return false;
   if(f == 0)
   {
      DrawStripUndoPush();
      DrawPresetApply(s_dsObj, 0);
      //--- P-DRAW-96 (2026-09-30): `DrawPresetApply` writes DRAW_SLOT_COLOR, so it owes
      //--- the box's own mid line the new ink — every other colour path in this group
      //--- carries `BoxMidSyncGroup()`/`BoxMidSyncServed()` for exactly that reason
      //--- (P-DRAW-64a), and Reset was the one that did not: after a Reset the 50 % line
      //--- kept the pre-Reset border colour until the pump's next pass. Served, not the
      //--- group: Reset touched the held drawing only.
      BoxMidSyncServed();   // P-DRAW-21: the level wears the border
      DrawStripPaint();
      return true;
   }
   if(f == 1)
   {
      DrawStyleApplyToKind(s_dsObj);
      DrawStripPaint();
      return true;
   }
   if(f == 2) return DrawStripDuplicate();
   return false;
}
//--- P-DRAW-117 (2026-10-01) — THE GROUP HEADER IS THE PANEL'S ONE GESTURE.
//--- A tap on a group's own row OPENS that group's settings (only one body is built
//--- at a time, so the group that was open folds); a tap on the group that IS open
//--- folds its body away and leaves the list — the panel stays open, with its head,
//--- its other groups and its foot exactly where they were. `s_dsGear` is still "the
//--- open group" (never 0 while the panel is open), so every reader that asks
//--- `s_dsGear != 0` keeps its answer, and `s_dsGearCollapsed` is the one new fact.
bool DrawStripGearGroupTap(const int gid)
{
   DrawStripColorHoverClear();
   if(!s_dsOpen) return false;
   bool known = false;
   for(int i = 1; i <= s_dsGearGrp[0]; i++) if(s_dsGearGrp[i] == gid) known = true;
   if(!known) return false;
   DrawStripClosePicker();
   if(s_dsGear == gid) s_dsGearCollapsed = !s_dsGearCollapsed;
   else { s_dsGear = gid; s_dsGearCollapsed = false; }
   // P-DRAW-26: the kind remembers its group (a shut panel remembers shut).
   if(s_dsKind > DK_NONE && s_dsKind < DK_COUNT) s_dsGearMem[s_dsKind] = s_dsGear;
   DrawStripLayout();
   DrawStripPaint();
   //--- P-DRAW-112 (2026-10-01): the census ran ONLY on the panel's OPEN, and a
   //--- tab switch is not an open — which is why every Style-tab report in the
   //--- 2026-10-01 log carries `PLATE tab=1` and not one `TABCENSUS` line: the one
   //--- walk that can name what the terminal actually holds for the tab that
   //--- misbehaves was never fired on it. Same owner, same bound (one walk per user
   //--- action, never per paint), and a GROUP OPEN is the same user action.
   //--- P-DRAW-123: and the walk now carries the paint's OWN declaration beside it
   //--- (`[dsdiag] EXPECT` + TABCENSUS of one state), which is what `tools/diag-diff.py`
   //--- diffs to name the objects the terminal did not honour.
   DrawStripGearDiagDump();
   return true;
}
//--- gear edits (ENDEDIT): hex colour, level add, caption. Invalid input keeps
//--- the typed text for another try (paint re-seeds a field only while it is NOT
//--- the focus, so an unparsable half-word is never overwritten under the hand).
//--- P-DRAW-100: AND THE COMMIT RELEASES THE FIELD. `s_dsHexFocus` is the guard the
//--- Paint tab's live re-seed asks, and only the BOARD's commit released it
//--- (P-DRAW-48, two lines below) — so one hex typed into the panel's own COLOR
//--- box armed the guard for the rest of the session and that field never showed a
//--- colour again. One line, at the one place the field stops being typed in, and
//--- an invalid parse keeps the focus so the hand's word survives either way.
bool DrawStripEditEnd(const int e)
{
   if(!s_dsOpen || s_dsObj == "") return false;
   string nm = DrawStripEditName(e);
   if(ObjectFind(0, nm) < 0) return false;
   string txt = ObjectGetString(0, nm, OBJPROP_TEXT);
   //--- P-DRAW-118 (2026-10-01): e0/e4 (the panel's two hex boxes) are RETIRED —
   //--- the colour is a swatch now and the exact value is the BOARD's HEX field,
   //--- whose own commit is `DrawStripPopHexEnd` below (P-DRAW-100's site moved with
   //--- the field). Their objects are swept by the paint's own `!want` branch, so a
   //--- chart that carried them keeps nothing.
   if(e == 1)
   {
      string t = txt;
      StringTrimLeft(t); StringTrimRight(t);
      //--- P-LVL-SCALE: typed percent rides /100 ("88.6" -> 0.886); a typed ratio
      //--- rides as-is ("0.5" -> 0.5). Guard is the ratio band now, not percent.
      double v = DrawStripLevelNorm(StringToDouble(t));
      if(!MathIsValidNumber(v) || v < -10.0 || v > 10.0) return true;
      if(DrawStripLevelFind(s_dsObj, v) >= 0) return true;
      DrawStripUndoPush();
      double vals[32]; color clrs[32]; int wds[32]; int sts[32]; string txts[32]; int n = 0;
      DrawStripLevelsCollect(vals, clrs, wds, sts, txts, n);
      if(n >= 32) return true;
      vals[n] = v;
      clrs[n] = (color)(int)DrawSlotRead(s_dsObj, DRAW_SLOT_COLOR);
      wds[n] = (int)DrawSlotRead(s_dsObj, DRAW_SLOT_WIDTH);
      sts[n] = (int)DrawSlotRead(s_dsObj, DRAW_SLOT_STYLE);
      txts[n] = "";
      n++;
      DrawStripLevelsRewrite(vals, clrs, wds, sts, txts, n);
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   //--- P-LVL-TEXT: the armed note commits onto its stored level (Enter). Empty
   //--- clears the note back to the value alone. Undoable like every look write.
   if(e == 4 && s_dsGear == DSTRIP_GEAR_LEVELS && DrawStripLvlDescWant())
   {
      string nt = txt;
      StringTrimLeft(nt); StringTrimRight(nt);
      if(StringLen(nt) > 63) nt = StringSubstr(nt, 0, 63);   // contract §2: object text truncates at 63
      DrawStripUndoPush();
      ObjectSetString(0, s_dsObj, OBJPROP_LEVELTEXT, s_dsLvlDescIdx, nt);
      s_dsLvlDescArmed = false;
      DrawStripDiagEmit("[drawstrip] LVLTEXT obj=\"" + s_dsObj + "\" level=" +
                        IntegerToString(s_dsLvlDescIdx) + " text=\"" + nt + "\"");
      DrawStripLayout();
      DrawStripPaint();
      ChartRedraw();   // P-UI-131: the line the user watches re-inks in its own frame
      return true;
   }
   if(e == 2 && DrawKindOf(s_dsObj) == DK_TEXT)
   {
      ObjectSetString(0, s_dsObj, OBJPROP_TEXT, txt);
      ChartRedraw();
      return true;
   }
   // P-DRAW-25: the armed save commits under the typed name (empty keeps the
   // "My N" fallback inside DrawPresetCapture). The file write is the commit.
   if(e == 3 && s_dsGear == DSTRIP_GEAR_TPL && s_dsTplNameArmed)
   {
      string t = txt;
      StringTrimLeft(t); StringTrimRight(t);
      DrawPresetCaptureAndSave(s_dsObj, t);
      s_dsTplNameArmed = false;
      DrawStripLayout();
      DrawStripPaint();
      return true;
   }
   return true;
}
//--- P-DRAW-13: the grip carry. Screen objects only (SELECTABLE=false), so the
//--- terminal never drags the plate for us and P-LM-11's race cannot happen — but
//--- the view lock IS needed now (P-UI-113d): the chart BEHIND the plate pans on
//--- a left drag, which is what made carrying the strip hard. Stale grabs (a
//--- motionless release emits no MOUSE_MOVE, P-LM-13) die on the next CLICK.
//--- P-DRAW-31 (2026-09-24) — THE PLATE IS A HANDLE, like a card's own skin. User
//--- order: «همه پنل ها درگ بشن راحت». The cards are carried by a press ANYWHERE on
//--- their chrome (`PnlSkinHit`); the strip answered only its 32px grip cell, so a
//--- hand that grabbed the plate by its title got nothing and the gesture fell
//--- through to the chart. The handle is the whole top row that carries no control —
//--- the grip cell and the BADGE beside it — plus the gear panel's own header bar
//--- while it is open, stopping `26 + 2 * pad` short of the close button's corner.
bool DrawStripGearGripAt(const int mx, const int my)
{
   if(!s_dsOpen || s_dsGear == 0 || s_dsGearHeadY < 0) return false;
   if(s_dsGearW0 <= 0 || s_dsGearH <= 0) return false;
   int hx = DrawStripGearX();
   if(my >= s_dsGEY + s_dsGearHeadY &&
      my <= s_dsGEY + s_dsGearHeadY + DSTRIP_GEAR_HEAD_H &&
      // P-DRAW-36: the handle spans the head's own width (s_dsGearW0) minus the
      // close button's corner — the same corner rule, measured off the plate.
      mx >= hx && mx <= hx + s_dsGearW0 - DSTRIP_GEAR_PAD - 26 - DSTRIP_GEAR_PAD) return true;
   return false;
}
//--- P-DRAW-113 (2026-10-01) — THE PANEL'S OWN PLATE IS NOT THE CHART, EVEN WHERE NO
//--- CONTROL IS. `DrawStripGearHit` answers "did a control act", and it answers FALSE
//--- on the panel's own dead pixels ON PURPOSE: the tab TRACK between two tabs
//--- (DrawStrip_Base.mqh:399), the 42px cell's own margins, and the plate's own 14px
//--- skin margin — which P-DRAW-83 already named as "pixels no control owns" without
//--- ever wiring them to anything.
//--- The press edge spent the event only on a TRUE (DrawStrip_Router.mqh:578), and the
//--- release's dismissal branch asks ONLY that flag — so a press on the panel's own
//--- dead space reached it unsunk and was read as a click on the CHART:
//--- `DrawStripClose()` → `DrawStripGearClose()` → `ObjectsDeleteAll("PnlDrawS_G")`,
//--- the whole family gone at once.
//--- MEASURED, EURUSD,H1 2026-10-01 10:14, Style tab: panel at (766,148) 624x398, and
//---   PLATE tab=1 ... xy=766,148 with the row's seats at 220/269/318/367 (w 41/45/37/37)
//---   [drawstrip] dismiss click at 1126,230 travel=0 obj="Rectangle 320"
//--- 230-148 = 82, inside the tab buttons' band (gy+65..gy+89); 1126-766 = 360, the 8px
//--- GAP between tab 2 (ends 359) and tab 3 (starts 367) — the track, the one place the
//--- hit test declines by design. The panel was torn down and came back with its head,
//--- its tab row and its foot gone: the report «خود تب و دکمه حذف و غیره دیده نمیشه».
//--- ONE owner, and it reads the panel's own numbers (`s_dsGEX/s_dsGEY/s_dsGearW0/
//--- s_dsGearH`), the same rect `DrawStripPointInside` and `DrawStripGearHit` already
//--- read. THE HEAD IS EXCLUDED: `DrawStripGearGripAt` is the panel's carry and needs
//--- the press left tracked, so the head's own band stays the carry's (P-DRAW-85).
bool DrawStripGearSurfaceAt(const int mx, const int my)
{
   if(!s_dsOpen || s_dsGear == 0) return false;
   if(s_dsGearW0 <= 0 || s_dsGearH <= 0) return false;
//--- ONE owner, ONE number. This is the same rect `DrawStripPointInside` answers for
//--- the panel (DrawStrip_Base.mqh:301-303) and it must carry the SAME margin: that
//--- function is the one the release's dismissal asks (`DrawStripPointInside`, router
//--- :988), and this one is the one that decides whether the press was spent. A press
//--- the release would call a dismissal but the press edge did not spend is exactly the
//--- `ObjectsDeleteAll("PnlDrawS_G")` this rule exists to stop — so both read
//--- `DSTRIP_SKIN_M + 2`, not two numbers 2px apart. The 2px is P-DRAW-31's air between
//--- the two surfaces, not a disagreement about where the panel ends.
int m = DSTRIP_SKIN_M + 2;   // the panel's own skin margin is plate, not chart
if(mx < s_dsGEX - m || mx > s_dsGEX + s_dsGearW0 + m) return false;
if(my < s_dsGEY - m || my > s_dsGEY + s_dsGearH + m) return false;
if(DrawStripGearGripAt(mx, my)) return false;   // the head is the carry's
return true;
}
//--- WHICH surface is under this press? 0 = neither · 1 = the strip's plate ·
//--- 2 = the settings panel. ONE reader (the carry), so the two gestures can never
//--- both own one press: the panel's header is asked FIRST, because a panel is
//--- never drawn on top of the strip's own row (`DrawStripPlaceGear` keeps them apart).
int DrawStripGripWhich(const int mx, const int my)
{
   if(!s_dsOpen) return 0;
   if(DrawStripGearGripAt(mx, my)) return 2;
   int rowY = s_dsY + DSTRIP_PAD;
   //--- P-DRAW-66: the identity group IS one handle — grip, its air and the name,
   //--- with no dead pixel between them (the old pair left the 4px gap ownerless).
   if(my >= rowY && my <= rowY + DSTRIP_CELL &&
      mx >= s_dsX + DSTRIP_PAD && mx <= s_dsX + s_dsBadgeX + s_dsBadgeW) return 1;
    // P-DRAW-48: the BOARD's own header carries the BOARD (its two seats — pin
    // and close — excluded). It is asked FIRST: the board can sit anywhere,
    // including over the strip, and a press on ITS header is never the strip's.
    if(DrawStripIsColorSlot(s_dsPicker) && s_dsBW > 0 && s_dsBH > 0 && s_dsPHeadY >= 0)
    {
       int hy0 = s_dsBY + s_dsPHeadY, hy1 = hy0 + DSTRIP_BOARD_HDR;
       int xx0 = s_dsBX + s_dsBW - DSTRIP_PAD - 2 * DSTRIP_PHEAD_XW - 2 - 2;
       if(my >= hy0 && my <= hy1 && mx >= s_dsBX && mx <= s_dsBX + s_dsBW && mx < xx0) return 3;
    }
    return 0;
}
#endif // DRAW_STRIP_TAP_MQH
// DrawStrip_Router.mqh - DrawStrip split 2026-09-29: exact lines 7019-7969 of DrawStrip.mqh, byte-identical, zero renames.
#ifndef DRAW_STRIP_ROUTER_MQH
#define DRAW_STRIP_ROUTER_MQH


void DrawStripGripMove(const int mx, const int my, const bool left)
{
   // P-DRAW-17: the press EDGE and the latch are the router head's (it runs on
   // every move, open or closed); this function only reads them.
   if(!s_dsOpen) { DrawStripGripRelease(); return; }
   if(left && s_dsLeftPress)
   {
      //--- P-PAL-21 (2026-10-02) — WHAT USED TO BE ASKED FIRST IS GONE. This press
      //--- edge owned the board: the opacity bar, the HSV studio, the two page
      //--- arrows and the palette scrub — five hit tests, each claiming the press
      //--- before the carries could see it, for a plate the strip no longer paints
      //--- (a colour cell opens the CARDS' palette, P-PAL-19). What remains is the
      //--- strip's own grip and the settings panel's, and they are the only two
      //--- things a press on this surface can be.
      int which = DrawStripGripWhich(mx, my);
      if(which != 0)
      {
         if(!s_dsGripLive && !s_dsGGripLive) ChartViewLockAcquire();   // P-UI-113d: the carry owns the view
         if(which == 2)
         {
            s_dsGGripLive = true;
            s_dsGGripDX = mx - s_dsGEX;
            s_dsGGripDY = my - s_dsGEY;
         }
         else
         {
            s_dsGripLive = true;
            s_dsGripDX = mx - s_dsX;
            s_dsGripDY = my - s_dsY;
         }
      }
   }
   if(!left)
   {
      DrawStripGripRelease();
      return;
   }
   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0); if(cw <= 0) cw = 1920;
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0); if(ch <= 0) ch = 1080;
   int gm = 4 + DSTRIP_SKIN_M;   // P-DRAW-29: the carried skin stays on screen
   //--- P-DRAW-32: the PANEL's own carry — its offset is off its own origin, so the
   //--- plate follows the hand exactly and the strip stays where it was put.
   if(s_dsGGripLive)
   {
      ChartViewLockAssert();
      uint nowG = GetTickCount();
      if(nowG - s_dsGGripMs < DSTRIP_GRIP_MS) return;
      s_dsGGripMs = nowG;
      int gx2 = mx - s_dsGGripDX, gy2 = my - s_dsGGripDY;
      if(gx2 < gm) gx2 = gm;
      if(gy2 < gm) gy2 = gm;
      if(gx2 > cw - s_dsGearW0 - gm) gx2 = cw - s_dsGearW0 - gm;
      if(gy2 > ch - s_dsGearH - gm) gy2 = ch - s_dsGearH - gm;
      if(gx2 == s_dsGEX && gy2 == s_dsGEY) return;
      s_dsGEX = gx2; s_dsGEY = gy2;
      s_dsGearManual = true;   // the hand placed the panel: keep its spot
      DrawStripPaint();
      return;
   }
   if(!s_dsGripLive) return;
   ChartViewLockAssert();   // P-BK-14: a third writer (a panel closing, a template reset) can
                            // flip the props back while the button is still down
   uint now = GetTickCount();
   if(now - s_dsGripMs < DSTRIP_GRIP_MS) return;
   s_dsGripMs = now;
   int nx = mx - s_dsGripDX, ny = my - s_dsGripDY;
   if(nx < gm) nx = gm;
   if(ny < gm) ny = gm;
   if(nx > cw - s_dsW - gm) nx = cw - s_dsW - gm;
   if(ny > ch - s_dsH - gm) ny = ch - s_dsH - gm;
   if(nx == s_dsX && ny == s_dsY) return;
   s_dsX = nx; s_dsY = ny;
   DrawStripHomeSet(s_dsX, s_dsY);   // P-DRAW-41: the hand just moved the home
   DrawStripPaint();
}


// ══════════════════════════════════════════════════════════════════════════
// P-UI-113 (2026-09-23, click-toggle 2026-10-07) — ONE CLICK OPENS THE STRIP.
// User order: «هولد بردار، کلیک که کرد و سلکت شد نوار فعال بشه» and «سلکت و
// دیسلکت با یک کلیک، نه دابل‌کلیک». The 500 ms hold is gone: a single click on
// one of the user's own drawings selects it and opens the strip; a single
// click on the served drawing deselects it and closes. No timers anywhere in
// this path — a press names, a release toggles, the opener window spends the
// twin. A drag never toggles (travel veto + the drag heartbeat below); a
// release never opens by itself.
// Zero-move presses emit no MOUSE_MOVE (P-LM-13) and need no poll: a click
// that names a drawing carries the name itself (OBJECT_CLICK sparam).
// ══════════════════════════════════════════════════════════════════════════
//--- P-UI-130 (2026-10-02) — A DRAWING THE TERMINAL IS MOVING IS NEVER TOGGLED.
//--- The user's second report, in one sentence: «موقعی که باکس جابجا میکنم یا
//--- ریساز میکنم نوار استریپ بالا میاد و مزاحم میشه». The press that STARTS a drag
//--- is a press on the drawing, so it arms the latch exactly like a hold does, and
//--- the 500 ms clock knows nothing about where the hand is going: the strip came
//--- up ON the drawing the user was about to move — and (P-UI-113f) left it
//--- natively selected while the anchors were being aimed at.
//---
//--- The witness is the terminal's OWN voice and this module already listens to
//--- it: CHARTEVENT_OBJECT_DRAG is fired for the user's gesture only (P-DRAW-64's
//--- interior rides it), it is the SAME trait P-BK-19a made the base box's owner
//--- (`BK_DRAG_OWNER_MS`: «a native drag announces itself with CHARTEVENT_OBJECT_DRAG
//--- this soon after the press»), and TH3Tool_C's band lock measured the resize
//--- half of it («MT4 fires CHARTEVENT_OBJECT_DRAG continuously while the user
//--- resizes the committed band»). So: the drag KILLS a live latch outright and
//--- FORBIDS the next one for as long as its own heartbeat keeps speaking.
//---
//--- The window is a HEARTBEAT, not a guess — the same shape as the band lock's
//--- `s_bandDragMs`. Events keep arriving while the object moves, so the window
//--- renews itself for exactly as long as the hand is moving the drawing, and
//--- past it the hand is at rest again (400 ms of silence = the drag is over).
//--- This is the protection the shortened press cycle (DSTRIP_PRESS_CYCLE_MS)
//--- traded away, and it is the honest swap: a PRESS is guarded by the press, a
//--- GESTURE IN MOTION by the motion.
#define DSTRIP_DRAG_HOLD_OFF_MS 400   // the drag heartbeat's own silence window
static uint   s_dsDragMs  = 0;         // last OBJECT_DRAG seen (the terminal's voice)
static string s_dsDragObj = "";        // the object it named
bool DrawStripDragLive()
{ return (s_dsDragMs != 0 && GetTickCount() - s_dsDragMs < DSTRIP_DRAG_HOLD_OFF_MS); }
//--- Called from the router's own OBJECT_DRAG branch, ABOVE every guard below (a
//--- drag with the strip OPEN still stamps: the strip may have to know the hand is
//--- on a drawing under it). Killing a latch costs two compares when none is live;
//--- the cycle goes with it because a press that has MOVED a drawing can never
//--- become a hold — the same law P-UI-113d wrote for the release (`relWasDrag`),
//--- applied at the moment the fact is measured instead of at the end of the press.
void DrawStripDragWitness(const string nm)
{
   s_dsDragMs  = GetTickCount();
   s_dsDragObj = nm;
   if(s_dsOpen) return;                       // an open strip owns no press naming
   if(!DrawStripPressCycleLive()) return;     // nothing named: nothing to drop
   Print("[drawstrip] press dropped: native drag obj=\"", nm, "\"");
   DrawStripPressCycleClear();   // proved a drag: this press may never become a tap
}
//--- P-UI-113c (2026-09-23) — THE OPENING PRESS OWNS ITS OWN CLICK-FAMILY EVENTS.
//--- Reported: «چرا با رها کردن هولد استریپ هم بسته میشه». The hold fires while the
//--- button is STILL DOWN, so the release that ends it lands on the drawing = the
//--- user's own click, and the outside-click dismissal read it as "clicked away" and
//--- closed the strip the hold had just shown: on with the press, gone on the release.
//--- A ONE-SHOT FLAG CANNOT FIX IT, and that is why this is a WINDOW: one physical
//--- release is reported on more than one channel (the chart's CHARTEVENT_CLICK and
//--- the object's CHARTEVENT_OBJECT_CLICK) and a one-shot spends the first while the
//--- second dismisses the strip. So the guard is armed for the PRESS CYCLE and
//--- re-armed by the press's own witnesses: ARM at the fire for
//--- DSTRIP_OPEN_PRESS_MAX_MS; the MOVE STREAM's release witness shortens it to
//--- DSTRIP_OPEN_TAIL_MS (the twin-event tail); a new press edge, a close or the TTL
//--- ends it. The state and its owners are in the file's state block above — the only
//--- place both sides can see.
void DrawStripHoldLatch(const int mx, const int my)
{
   // Press NAMING (the fire-on-timer is gone; the click toggles). Hit-test the
   // press pixel, set the press cycle when it names a drawing, fence sessions.
    //--- P-UI-130: THE TERMINAL IS MOVING A DRAWING — the hand is not pressing it. FIRST
    //--- because it is one compare, and a press during a live drag names nothing.
    if(DrawStripDragLive())
    {
       if(!s_dsOpen) Print("[drawstrip] latch blocked: native drag obj=\"", s_dsDragObj, "\"");
       return;
    }
    string named = DrawObjectAtCached(mx, my);   // the one hit test this latch pays for
    DrawStripOpenerDisarm();   // P-UI-113c: a new press is never the old gesture
   //--- DIAG-116 (temporary, P-UI-115b). These seven fences return SILENTLY, so
   //--- a press they swallow leaves no line anywhere: the 2026-09-29 log has NO
   //--- `hold latch` at all after the 13:35 reload, and a line that is never
   //--- printed cannot say WHICH fence did it (or whether the edge ever came).
   //--- Each fence now names itself, only while the strip is shut - i.e. exactly
   //--- the state a hold opens from, and one line per press. Remove with DIAG-113.
   if(BaseKnotSessionActive()) { if(!s_dsOpen) Print("[drawstrip] latch blocked: baseknot session"); return; }
   if(UIPeekClickClaim())      { if(!s_dsOpen) Print("[drawstrip] latch blocked: ui peek claim"); return; }
   if(UIPointerOverSurface(mx, my)) { if(!s_dsOpen) Print("[drawstrip] latch blocked: ui pointer over surface at ", mx, ",", my); return; }
   if(BaseKnotViewOwned())     { if(!s_dsOpen) Print("[drawstrip] latch blocked: baseknot view owned"); return; }
   if(TH3SessionActive() || TH3BaseMarkArmed()) { if(!s_dsOpen) Print("[drawstrip] latch blocked: th3 session"); return; }
   if(LegMeasureSessionActive()) { if(!s_dsOpen) Print("[drawstrip] latch blocked: leg measure session"); return; }
   if(g_waitingForCustomPriceClick) { if(!s_dsOpen) Print("[drawstrip] latch blocked: waiting for custom price click"); return; }
   // P-UI-113j: NAME THE PRESS'S OWN DRAWING - and name it even while the strip is
   // OPEN, because the release that follows belongs to the same press and the
   // terminal's selected controls are not part of any drawn body. Cost: the one
   // hit test this latch already pays for on a press edge (P-DRAW-04), memoised;
   // the guards above stay first so a session that owns the mouse pays nothing.
    s_dsPressX = mx; s_dsPressY = my; s_dsTravel = 0; s_dsPressTracked = true;
    // P-UI-115: THE CYCLE BELONGS TO A PRESS THAT NAMED A DRAWING. A press on
    // empty chart names nothing, and it has nothing to open — it must not spend
    // the gesture budget of the press after it.
    if(named != "") DrawStripPressCycleSet(named);
    if(s_dsOpen) return;   // an open strip owns no press cycle - the press is only NAMED
    // DIAG-113 (temporary): one line per named press so the log proves whether the
    // press reached us, what the hit test saw, and what the live probe reads.
    Print("[drawstrip] press named at ", mx, ",", my, " hit=\"", named,
          "\" lbtn=", (UILeftButtonDown() ? 1 : 0));
}
//--- P-UI-113f (2026-09-24): THE CLICK LEAVES THE DRAWING NATIVELY SELECTED.
//---
//--- The strip's rectangle hit test deliberately owns a hollow box's INTERIOR
//--- (P-DRAW-08g), while MT4's own hit test sees only the drawn border. Therefore
//--- a hold can open the strip on a box that the terminal never selected; the
//--- release is then an empty-chart click and the eight resize anchors / native
//--- settings never appear. The user order is the terminal's own object model, not
//--- a second selection: a successful hold must leave an unlocked user drawing
//--- selected, so MT4 keeps its anchors, right-click properties and resize handles.
//---
//--- This is deliberately NOT a SELECTABLE write. Lock stays the lock, and an
//--- already-selected drawing pays no object write. The release reasserts the same
//--- fact because MT4 can clear selection immediately before reporting the click;
//--- the opening-press window bounds that repair to this exact gesture.
bool DrawStripHoldSelect()
{
   string nm = s_dsObj;
   if(nm == "" || ObjectFind(0, nm) < 0) return false;
   if(DrawKindOf(nm) == DK_NONE) return false;
   if(DrawIsHRay(nm)) return true;   // P-HR-04: the dot IS the selection — nothing to assert
   if(DrawIsPathSeg(nm)) return true;   // P-UI-136: the handles are the path's selection
   if(DrawIsIndicatorObject(nm)) return false;
   if(!(bool)ObjectGetInteger(0, nm, OBJPROP_SELECTABLE)) return false;
   if((bool)ObjectGetInteger(0, nm, OBJPROP_SELECTED)) return true;
   return ObjectSetInteger(0, nm, OBJPROP_SELECTED, true);
}
//--- P-UI-113g: arm the post-callback repair. Fire arms it too because MT4 may
//--- clear the selection before the physical release even arrives; every opening
//--- release re-arms the short window with a fresh post-event deadline.
void DrawStripHoldSelectArm()
{
   if(s_dsObj == "") return;
   uint now = GetTickCount();
   s_dsSelectRepairName = s_dsObj;
   s_dsSelectRepairAt = now + DSTRIP_SELECT_REPAIR_DELAY_MS;
   s_dsSelectRepairUntil = now + DSTRIP_SELECT_REPAIR_TTL_MS;
}
void DrawStripHoldSelectPoll()
{
   if(s_dsSelectRepairUntil == 0) return;
   uint now = GetTickCount();
   if(!TickDeadlinePending(s_dsSelectRepairUntil)) { DrawStripHoldSelectionDisarm(); return; }
   if(!TickDeadlinePending(s_dsSelectRepairAt)) return;   // still inside the release callback/tail
   if(!s_dsOpen || s_dsObj == "" || s_dsSelectRepairName != s_dsObj)
   { DrawStripHoldSelectionDisarm(); return; }

   bool wasSelected = (ObjectFind(0, s_dsObj) >= 0 &&
                       (bool)ObjectGetInteger(0, s_dsObj, OBJPROP_SELECTED));
   if(!DrawStripHoldSelect()) { DrawStripHoldSelectionDisarm(); return; }
   if(!wasSelected)
   {
      ChartRedraw();
      Print("[drawstrip] native selection repaired after release obj=\"", s_dsObj, "\"");
   }
   // Keep the guarded read alive until the short TTL: the timer is the proof that
   // MT4's delayed click state has committed. It never owns selection afterwards.
}
// P-UI-113d CLICK-TOGGLE (2026-10-07) — single click selects+opens, single
// click deselects+closes. No hold, no double-click. Decided by STRIP STATE,
// never by selection state (MT4 mutates selection around the click event, so
// no order of native-vs-handler writes can misread it). A drag-release never
// toggles (travel veto + the drag heartbeat); a modal card owns its clicks.
// Returns true when the click was spent here.
// Leaned on: DrawStripOpenAt validates + switches (s_dsObj==name re-states),
// DrawStripClose is idempotent, DrawStripDragLive is the terminal's own drag
// voice, DrawStripOpenerArm spends this release's twin.
bool DrawStripClickToggle(const string nm, const bool wasDrag)
{
    if(nm == "" || ObjectFind(0, nm) < 0) return false;
    if(wasDrag) return false;               // P-UI-113d: a drag-release never toggles
    if(DrawStripDragLive()) return false;   // P-UI-130: the terminal is still moving it
    if(g_PnlOpen >= 0) return false;        // modal card/mini owns clicks
    if(BaseKnotSessionActive() || TH3SessionActive() || TH3BaseMarkArmed() ||
       LegMeasureSessionActive() || g_waitingForCustomPriceClick) return false;
    if(s_dsOpen)
    {
        if(nm == s_dsObj)
        {
            // P-UI-155: twin of this gesture's own fallback open (the chart
            // channel arrived first on a hollow interior) — spent here, never
            // closed. Time-bounded (twin channels arrive milliseconds apart),
            // never token-counted: a stale token budget ate genuine clicks for
            // ten seconds. A genuine second click after the deadline closes.
            if(DrawStripTwinSpent()) return DrawStripClickFamily();
            if((bool)ObjectGetInteger(0, nm, OBJPROP_SELECTED))
                ObjectSetInteger(0, nm, OBJPROP_SELECTED, false);   // single-click deselect
            Print("[drawstrip] click closed on \"", nm, "\"");
            DrawStripClose();
            DrawStripOpenerArm();   // this release's twin is spent, not a re-open
            return DrawStripClickFamily();
        }
        // Switch candidate: validate BEFORE touching anything — panel buttons,
        // menu buttons and foreign lines are not ours and must fall through.
        if(DrawKindOf(nm) == DK_NONE) return false;
        DrawStripGearClose();   // switch: the gear panel serves one drawing; reopen it there if wanted
        DrawStripClose();
    }
    if(!DrawStripOpen(nm)) return false;
    // P-HR-06: the dot IS the ray's selection — no native flag to assert and no
    // repair poll to arm (that poll would redraw + log on every ray open).
    if(!DrawIsHRay(nm) && !DrawIsPathSeg(nm))
    {
        DrawStripHoldSelect();     // P-UI-113f: native anchors/settings survive the click
        DrawStripHoldSelectArm();  // P-UI-113g: prove it again after MT4 commits the release
    }
    DrawStripOpenerArm();   // P-UI-113c: the click that opened it owns its twin
    Print("[drawstrip] click opened on \"", nm, "\" selected=",
          (bool)ObjectGetInteger(0, nm, OBJPROP_SELECTED));
    return DrawStripClickFamily();
}
//--- P-UI-113i (2026-09-24): RELEASE OWNERSHIP IS GEOMETRY, NOT SELECTION STATE.
//--- User proof: the same left release works while the drawing is unselected and
//--- closes the strip while that drawing is selected. The old dismissal asked
//--- only whether the release pixel was on the drawn body; MT4's selected controls
//--- are terminal UI, not the object, so a release there read as outside. The
//--- robust contract is wider: a release belongs to the strip's drawing when the
//--- PRESS already named that drawing, OR when the release pixel still resolves to
//--- it through the same body/control hit test. Selected or not is therefore not a
//--- branch: both states feed this one owner and produce the same answer.
bool DrawStripReleaseOnDrawing(const string pressedName, const int px, const int py)
{
   if(s_dsObj == "" || ObjectFind(0, s_dsObj) < 0) return false;
   if(pressedName != "" && pressedName == s_dsObj) return true;
   // A motionless press emitted no move edge to clear the gesture memo. At the
   // release there is no earlier answer worth trusting, so this fallback takes a
   // live hit test instead of inheriting the same pixel's last 400 ms owner.
   DrawHitCacheClear();
   return (DrawObjectAtCached(px, py) == s_dsObj);
}

//--- THE EVENT ROUTER. Called from the entry's OnChartEvent tail (Full only):
//--- it sees the button clicks the terminal reports and the clicks that land
//--- anywhere else (which dismiss the strip, TV-style).
bool DrawStripOnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // P-UI-113d: the button-up's OWN fact, measured once in the click head below
   // and read by the dismissal at the tail of this one call (the two halves are
   // one invocation, so this is a local, not state).
   bool relWasDrag = false;
   string relPressObj = "";   // P-UI-113i: this button-up's own press owner
   static uint s_drN = 0;      // DIAG-140: drag events in the open window
   static uint s_drMs = 0;     // ...window start (ms)
   static string s_drObj = ""; // ...owner under the hand
   //--- P-DRAW-64 addendum 5 (2026-09-27) — THE INTERIOR'S STEP IS NOT THE STRIP'S.
   //--- This witness stands ABOVE EVERY GUARD below, because the split belongs to
   //--- the DRAWING: with the strip shut, the old placement sat two hundred lines
   //--- further down and returned first, so a box dragged then kept its pre-drag
   //--- interior until the pump's 2 s pass («این باکس هنوز همین طوریه … اون fill
   //--- ریل تایم همراه جابجا نمیشه»), and the terminal's own properties dialog fires
   //--- no drag event at all. Cost per witness: 1-2 compares for a line or any other
   //--- kind, ~12 guarded reads for a user FILLER kind, a write only on a real move.
   if((id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE) && sparam != "")
   {
      //--- P-UI-130: THE DRAWING IS MOVING, SO NOTHING MAY BE HELD ON IT. Only the
      //--- DRAG channel is the hand (OBJECT_CHANGE is the properties dialog: a still
      //--- hand, no gesture in flight to end).
      if(id == CHARTEVENT_OBJECT_DRAG) DrawStripDragWitness(sparam);
      //--- P-DRAW-64 addendum 6: the drag event stamps, and it ARMS the move memo, so
      //--- a frame the terminal coalesces away is still covered by the hand's own stream.
      FillChildStampArm(sparam);
      FillChildSync(sparam);
      //--- P-DRAW-64d (2026-09-27): THE LEVEL RIDES THE SAME EVENT. The mid line's own
      //--- sync sat two hundred lines down, BELOW the shut-strip guard — so a box dragged
      //--- with the strip shut kept its pre-drag level until the pump's 2 s pass (the
      //--- stuck dotted line in the user's screenshot: «این خط 50 درصد چند فریم عقب زمانی
      //--- که باکس و جابجا میکنم»). It stands here now, beside the interior, UNTHROTTLED:
      //--- the moves below are guarded, so a still frame is reads and never a repaint,
      //--- and the hand's own cadence IS the cadence (the realtime law — a 50 ms cap on
      //--- a hairline is three frames the user explicitly refused). The pump stays the
      //--- net for gestures that fire no event at all.
      BoxMidSync(sparam);
      FibPenSync(sparam, false);   // P-DRAW-74b: the pair rides the same event (reads on a still frame)
      // P-DRAGF: arm the chase — the drag event names the hand's object, the moves
      // do the following (FibPen.mqh). Drag-rate cost: kind + existence reads.
      if(id == CHARTEVENT_OBJECT_DRAG) FibPenDragArm(sparam);
      // P-DRAW-74b-f (2026-10-03) — A DRAG FLUSHES ITS OWN FRAME. The terminal
      // blits the dragged master live and repaints followers on its own cadence,
      // so a resized fibo's stack trailed one frame behind for the whole gesture
      // («موقع ریسایز کردن فریمش عقب میمونه»). P-DRAW-127's law, same shape as the
      // GEAR branch: a user action gets one flush, a paint pass never does.
      ChartRedraw();
      // DIAG-140 (2026-10-03) — THE DRAG RATE, MEASURED NOT GUESSED. A lag report
      // during a gesture is either an event queue the handler cannot drain or
      // paint the terminal defers — events per second tell which. One line per
      // gesture-second; still frames are silent.
      if(id == CHARTEVENT_OBJECT_DRAG)
      {
         uint nowMs = GetTickCount();
         if(s_drObj != sparam || nowMs - s_drMs >= 1000)
         {
            if(s_drN > 0 && s_drObj != "")
               DrawStripDiagEmit("[drawstrip] DRAGSTAT obj=\"" + s_drObj + "\" n=" + IntegerToString(s_drN));
            s_drObj = sparam; s_drN = 0; s_drMs = nowMs;
         }
         s_drN++;
      }
   }
   // P-DRAW-17: the left button's press edge and travel, on EVERY move — the
   // trigger needs them while the strip is CLOSED, the grip carry needs the edge
   // while it is OPEN. Computed once here, read by both.
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int tmx = (int)lparam, tmy = (int)dparam;
      int mstate = (int)StringToInteger(sparam);
      bool tleft = ((mstate & 1) != 0);
      // P-UI-113b (2026-09-23) — THE PRESS EDGE IS A STORE, NOT A COMPARISON.
      //
      // The P-UI-114 sweep moved the edge's computation out of `DrawStripGripMove`
      // (which stored `s_dsLeftPrev = left;` at its tail) into this head and left
      // the store behind, so `s_dsLeftPress` WAS `tleft`: every move under a held
      // button read as a fresh press. Measured on the live chart (EURUSD,H1,
      // 20:17:21-25): one press on `Rectangle 664` produced eight `[drawstrip]
      // hold latch` lines in 4.7 s, because the hold's latch — and `s_dsHoldMs`
      // with it — was re-armed on every one of them, so the 500 ms clock kept
      // restarting and `hold opened` never printed once. The grip carry's own
      // press edge was equally false. One store per move is the whole fix.
      s_dsLeftPress = (tleft && !s_dsLeftPrev);
      s_dsLeftPrev = tleft;
      if(s_dsLeftPress)
      {
         //--- DIAG-116 (temporary): THE EDGE ITSELF. Every witness downstream prints
          //--- only once the press reached IT, so a press that dies before the latch
          //--- is invisible by construction - and that is the whole state of the
          //--- 2026-09-29 log after the 13:35 reload (no line of any kind). Gated to
          //--- the shut strip: a toggle only opens from there, and an open strip's
          //--- presses are the panel's own. One line per press edge.
         if(!s_dsOpen) Print("[drawstrip] press edge at ", tmx, ",", tmy, " bit=", (tleft ? 1 : 0));
          // P-UI-113j: the latch names this press (a flapping bit re-reports ONE
          // press as many). Its owner, its press point and the opening window
          // survive untouched - re-declaring them here is what let a mid-press
          // flap kill the window.
          if(!DrawStripPressCycleLive())
          {
             s_dsPressX = tmx; s_dsPressY = tmy; s_dsTravel = 0;
             s_dsPressEdgeMs = GetTickCount();   // P-UI-155: freshness stamp for the travel veto
             s_dsPressTracked = true;   // P-UI-113d: this cycle's travel is a fact we own
             //--- P-DRAW-102: A NEW PRESS IS NEVER THE PREVIOUS GESTURE'S RELEASE.
             //--- `s_dsGearPressSpent` is armed by the panel's coordinate channel
             //--- below and spent by the release that follows it, and the only other
             //--- places that clear it are the panel's close and the strip's. A press
             //--- on a control whose release the terminal never reported as a click
             //--- (the hand let go outside the chart window) left it armed, and the
             //--- NEXT click on the chart was spent at 682 as a twin release: the
             //--- click the user made to dismiss the strip did nothing, and the one
             //--- after it worked. It is this press's own flag, so a new press edge
             //--- is where it starts again — set below, on the same block.
             s_dsGearPressSpent = false;

            DrawHitCacheClear();   // the hit memo is a GESTURE's, never a session's
            s_dsPressObj = DrawObjectAtCached(tmx, tmy);  // P-UI-113i: own the press
            FillChildStampArm(s_dsPressObj);   // P-DRAW-64 addendum 6: the hand's own ride
             DrawStripOpenerDisarm();   // P-UI-113c: a NEW press is never the old gesture
             DrawStripHoldSelectionDisarm();  // P-UI-113g: nor may the repair fight it
             DrawStripHoldLatch(tmx, tmy);   // names the press hit + sets the cycle (was the step's call)
            //--- P-DRAW-84 (2026-09-29) — THE PANEL'S BUTTONS, ON THE PRESS EDGE.
            // Every painter in this file is born OBJPROP_SELECTABLE=false (3317,
            // 3366, 3413, 3444), so MT4 never fires OBJECT_CLICK for a control and
            // the panel's name router (7538+) could not answer a single tab, row,
            // switch or foot button. The cards work because BiotakPanels has
            // P-UI-74's coordinate channel (PnlClickFallback, called at 9488
            // before the name router). This is that channel, on the press edge —
            // which fires for EVERY press, whatever object (or none) is under the
            // cursor, so it is the only place that does not depend on which event
            // MT4 chose. Routed to the SAME *Tap functions the name router calls,
            // so no action logic was duplicated. The panel is a surface of its own
            // (DrawStripPointInside:953), so this press is never a chart press.
            //
            // It does NOT return: this is the middle of the mouse-move block, and
            // an early return here would also cancel the hover, the hold latch and
            // the travel bookkeeping every later branch below this one owns. It
            // only SPENDS the press — the carry and the opener are
            // disarmed, so the rest of this block finds nothing to do with it.
            //
            //--- P-DRAW-113 (2026-10-01): AND `DrawStripGearSurfaceAt` IS THE OTHER
            //--- HALF OF THAT SENTENCE. `DrawStripGearHit` declines the panel's own
            //--- dead pixels — the tab TRACK between two tabs (Base:399), a cell's
            //--- margins, the plate's own skin margin — and the release below asks
            //--- ONLY this flag, so a press there read as a click on the chart and
            //--- `ObjectsDeleteAll("PnlDrawS_G")` took the head, the tab row and the
            //--- foot with it. MEASURED (H1 10:14:30 `dismiss click at 1126,230`
            //--- against `PLATE tab=1 ... xy=766,148`: 82px down = inside the tab
            //--- buttons, 360px across = the 8px gap between tab 2 and tab 3).
            //--- The panel is a surface of its own, so a press on ANY of its pixels
            //--- is spent here; its head stays out of it, because that band is the
            //--- panel's carry and needs the press left tracked (P-DRAW-85).
            if(s_dsGear != 0 &&
               (DrawStripGearHit(tmx, tmy) || DrawStripGearSurfaceAt(tmx, tmy)))
            {
               s_dsPressTracked = false;        // the panel had it: not a carry
               DrawStripPressCycleClear();
               DrawStripOpenerDisarm();
               DrawStripHoldSelectionDisarm();
               s_dsGearPressSpent = true;       // the release knows the panel had it
            }
         }
         else if(!s_dsOpen) Print("[drawstrip] press refused: cycle live obj=\"", s_dsPressCycleObj, "\"");
       }
       else if(tleft)
      {
         int adx = tmx - s_dsPressX; if(adx < 0) adx = -adx;
         int ady = tmy - s_dsPressY; if(ady < 0) ady = -ady;
         if(adx + ady > s_dsTravel) s_dsTravel = adx + ady;
         //--- P-DRAW-64 addendum 6: under a held button the interior rides the HAND.
         //--- One compare against the memo's four values; a frame that really moved
         //--- pays the guarded sync, a still frame costs four reads and nothing else.
         FillChildStamp(s_dsPressObj);
      }
       else if(s_dsOpenerUntil != 0)
       {
          // P-UI-113c: THE STREAM'S OWN RELEASE WITNESS. The opening press is
          // over, so the guard drops to the twin-event tail: the terminal's other
          // report of this ONE release may still be in flight behind this move.
          s_dsOpenerUntil = 0;
          s_dsOpenerTailUntil = GetTickCount() + DSTRIP_OPEN_TAIL_MS;
       }
        if(!tleft) DrawStripColorHoverAt(tmx, tmy);
       //--- P-DRAGF2 (2026-10-04) — THE CHASE IS THE DRAWING'S, NOT THE STRIP'S. The
       //--- follow used to sit BELOW the shut-strip guard (the second MOUSE_MOVE branch,
       //--- with the grip carry), so with the strip shut a dragged fibo's stack moved
       //--- ONLY on the terminal's own drag events — measured DRAGSTAT 0.6-1.6 s apart —
       //--- the same shape P-DRAW-64d fixed for the box's mid line one seat down
       //--- («این خط 50 درصد چند فریم عقب زمانی که باکس و جابجا میکنم»). A drawing's
       //--- followers belong to the drawing: the chase stands here, above every guard,
       //--- beside the press edge that already owns the button. Cost with nothing armed:
       //--- two compares.
       // P-DRAGF: the chase rides the hand's own stream — drag events arrive ~1-2/s
       // (measured DRAGSTAT) while moves arrive ~60-100/s. Button-held only;
       // anything else disarms instead of following.
       if(tleft) FibPenDragFollow((int)lparam, (int)dparam);
       else FibPenDragDisarm();
    }

    // P-DRAW-17: THE OPEN PATH RUNS BEFORE THE GUARD — the guard below says the strip
    // must be open, and the open trigger used to sit under it ("the strip never appears").
    // P-UI-113/113b — the release that ENDS the opening click belongs to the gesture that
    // opened it, so it is SPENT as a WINDOW (P-UI-113c, `s_dsOpenerUntil`), never as a
    // one-shot: one physical release arrives on CHARTEVENT_CLICK and on the object's
    // OBJECT_CLICK, and spending only the first lets the second dismiss the strip the click
    // just opened — or, landing on the strip's own cells (it floats 12 px off the cursor),
    // DELETE the drawing. MT4 has exactly two release channels and neither is ever a press,
    // so the press is NAMED from the mouse stream's own edge and the toggle answers here.
     if(id == CHARTEVENT_CLICK || id == CHARTEVENT_OBJECT_CLICK)
     {
         // P-UI-115 (2026-09-29) — THE PROBE MAY NOT GATE THE RELEASE. This read
         // `if(UILeftButtonDown()) return true;` and skipped the WHOLE block below
         // — including the tail that ends the press cycle — whenever the
         // terminal's KEYSTATE probe said "pressed", which on this terminal is
         // every time: the 2026-09-29 log prints `lbtn=1` on all 368
         // `[drawstrip] hold latch` lines, one of them 11 ms after attach when no
          // button can be down. The cycle the tail ends lives
          // `DSTRIP_OPEN_PRESS_MAX_MS` = 10 s. Latch-to-latch spacing in the log
          // was exactly 10 s (`12:53:07 -> :17 -> :27`) while the cycle lived that
          // long; it lives 2 s now (DSTRIP_PRESS_CYCLE_MS) and every release ends
          // it above. The fence was also the opposite of the law the comment below
          // states — «a click-family event IS a release on this terminal» — and
          // MT4 emits a click on release only, so the release is not a probe's to
          // guess.
         if(UIPeekClickClaim()) return true;
         // P-UI-113c: the opening press cycle owns its own events — all of them.
         bool openerSpent = DrawStripOpenerClickSpent();
       // P-UI-113d: and this is where the BUTTON-UP's own fact is measured — a
       // release whose hand left its press point is the END OF A DRAG (of the
       // drawing, of the plate, or of the chart), never the "clicked away"
       // gesture the TV-style dismissal below is for. Measured HERE because this
       // is also the event that ends the press cycle.
       relWasDrag = (s_dsPressTracked && s_dsTravel > DSTRIP_CLICK_SLOP);
       relPressObj = s_dsPressObj;   // P-UI-113i: keep the press owner for the tail
       // P-UI-113j: ELSE THE LATCH'S OWN OWNER. A still press left no move edge, and
       // the terminal's LIVE selection is not a fact this release may ask: MT4
       // clears it around its own click, and the control the hand is on stops being
       // part of any drawn body at that exact moment.
       if(relPressObj == "") relPressObj = s_dsPressCycleObj;
       //--- P-DRAW-64 addendum 5 (2026-09-27): THE RELEASE RE-STAMPS THE CHILDREN.
       //--- A gesture's LAST drag frame can be coalesced away, and a release is the
       //--- end of every gesture AND names its own object — so this one call is the
       //--- cheap witness that repairs it in the frame the hand lets go, before the
       //--- dismissal below can return. Once per gesture, ~12 guarded reads.
         if(relPressObj != "")
         {
            FillChildSync(relPressObj);
            BoxMidSync(relPressObj);
            FibPenSync(relPressObj, false);   // P-DRAW-74b: the release re-states the pair too
            FibPenDragDisarm();   // P-DRAGF: the gesture is over, the chase stands down
            ChartRedraw();   // P-DRAW-74b-f: the release flushes the re-stamp
         }
        FillChildStampRelease();   // P-DRAW-64 addendum 6: the hand let go, so the memo rests

       s_dsPressObj = "";

       s_dsPressTracked = false;
       DrawStripPressCycleClear();   // no pending fire exists: every release ends its press here
       if(openerSpent)
       {
          DrawStripHoldSelect();   // P-UI-113f: the release must not steal the anchors back
          DrawStripHoldSelectArm();  // P-UI-113g: repair it again AFTER the callback
          return true;
       }
       // CLICK-TOGGLE: a named click on a drawing opens/closes/switches the strip.
       if(id == CHARTEVENT_OBJECT_CLICK)
       {
          if(DrawStripClickToggle(sparam, relWasDrag)) return true;
       }
       DrawStripHoldSelectionDisarm();  // P-UI-113g: a later click owns selection now
       s_dsLeftPrev = false;   // (every release emits one: the boxes' own law, BkHoldOnBoxUp)
    }
    // P-UI-155 (2026-10-08) — A CLICK INSIDE A HOLLOW DRAWING NAMES NOTHING AT
    // RELEASE. MT4 hit-tests only the drawn border, so a release inside a
    // rectangle arrives as a chart click while the PRESS already named it (our
    // hit test owns the interior, P-DRAW-08g) — measured: five named presses
    // on one rectangle, zero opens, while the trendline beside it opened every
    // time. Decide by EITHER channel: the release pixel re-resolves live, else
    // the press cycle answers (fresh, 2 s TTL). The travel veto reads only a
    // FRESH edge: a zero-move press runs no edge, so stale travel from a
    // previous drag must not refuse it (it may still refuse nothing else —
    // a drag always moves, so its edge is fresh by definition). Every other
    // veto still applies inside DrawStripClickToggle. The open arms the twin
    // flag, so whichever channel arrives second is spent instead of closing.
    if(id == CHARTEVENT_CLICK && !s_dsOpen)
    {
       DrawHitCacheClear();   // the release pixel deserves a live answer, not the press memo
       int rx = (int)lparam, ry = (int)dparam;
       string relHit = DrawObjectAtCached(rx, ry);
       string cyc = (DrawStripPressCycleLive() ? s_dsPressCycleObj : "");
       string nm = (relHit != "" ? relHit : cyc);
       bool edgeFresh = (s_dsPressEdgeMs != 0 && (int)(GetTickCount() - s_dsPressEdgeMs) < DSTRIP_PRESS_CYCLE_MS);
       bool travelOk = !edgeFresh || !(s_dsPressTracked && s_dsTravel > DSTRIP_CLICK_SLOP);
       // DIAG-156 (temporary): name the refusing stage for hollow-interior clicks.
       if(nm != "") Print("[drawstrip] interior-click relHit=\"", relHit, "\" cyc=\"", cyc,
             "\" edgeFresh=", (edgeFresh ? 1 : 0), " travel=", s_dsTravel,
             " draglive=", (DrawStripDragLive() ? 1 : 0),
             " modal=", (g_PnlOpen >= 0 ? 1 : 0));
       if(nm != "" && ObjectFind(0, nm) >= 0 && DrawKindOf(nm) != DK_NONE && travelOk)
       {
          if(DrawStripClickToggle(nm, false)) { DrawStripTwinArm(); return true; }
       }
       return false;
    }
    if(id == CHARTEVENT_CLICK && !s_dsOpen) return false;
    // P-DEL-NOWb: a delete is not a click — the shut-strip gate above exists so
    // a release cannot open anything, but it also buried the OBJECT_DELETE
    // branch below: with the strip shut (the normal state) no native delete
    // ever cascaded, and every fill fell through to the 2 s orphan sweep
    // («fill دیرتر پاک میشه», measured: ORPHAN drops for Rectangle _FL while
    // no CASCADE line preceded them). Deletes skip the gate, clicks keep it.
    if(!s_dsOpen && id != CHARTEVENT_OBJECT_DELETE) return false;
     //--- P-DRAW-84: the gear panel's press already acted (7337). This release is
     //--- the SAME gesture on the other channel: it must be spent here, or the
     //--- "clicked away" branch below reads a press on the panel as a press on the
     //--- chart and shuts the panel the user was working in.
     //--- P-DRAW-115 (2026-10-01) — AND THE FLAG'S LIFETIME IS THE GESTURE, NOT THE
     //--- FIRST EVENT THAT SEES IT. `s_dsGearPressSpent = false` stood HERE, and this
     //--- branch is the one place every release passes: MT4 reports ONE release on TWO
     //--- channels (`CHARTEVENT_OBJECT_CLICK` and `CHARTEVENT_CLICK`), so the first one
     //--- consumed the flag and the second found it clear and fell through into the
     //--- dismissal at 951 — where the release pixel is asked `DrawStripPointInside`.
     //--- P-DRAW-84's own arming note (553) says the lifetime is the gesture: the flag
     //--- is armed by the press edge and cleared by the NEXT press edge, by the panel's
     //--- close (DrawStrip_GearB:83) and by the strip's open (DrawStrip_Paint:702).
     //--- This line was the fourth writer and the only one that shortened it.
     //--- WHY IT SHOWS AS «PANEL HALF GONE» AND NOT AS A STUCK TAB: the press edge
     //--- ALREADY acted (598), and a tab press re-lays-out and re-places the plate —
     //--- MEASURED in one log second: `PLATE tab=5 ... xy=196,37` then
     //--- `PLATE tab=1 ... xy=196,18`, and the tab seats move with it
     //--- (`GT2 356,102` -> `GT2 512,83`). So by the time the second channel arrives,
     //--- the control under the hand is a different one and the plate under the release
     //--- pixel may not be the plate at all: `DrawStripClose()` runs, and it is
     //--- `ObjectsDeleteAll("PnlDrawS_G")` — the head, the tab row and the foot with it.
     //--- The cards never had this shape: `PnlClickFallback` spends the gesture and the
     //--- press chain consumes the echo (`s_PnlClickActed`), ONE arbiter for two
     //--- channels. This flag is that arbiter; it now has the lifetime the cards' has.
     if(s_dsGearPressSpent)
        return DrawStripClickFamily();
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
       // P-UI-113-OFF (2026-09-23): the closed-state right-click open channel
       // retired with the trigger — unreachable now (`!s_dsOpen` returned above).
        if(!s_dsOpen) return false;
        DrawStripGripRelease();   // a click ends any grip carry (stale-grab net)
        //--- P-DRAW-84: the panel's coordinate channel lives on the PRESS EDGE
        // (7337), not here. It cannot live here alone: every control in this file
        // is non-selectable, so this event never fires for one, and a second call
        // would fire the same control twice on a release that does arrive.
        if(sparam == DrawStripGearCloseName() || sparam == DrawStripGearCloseSkinName() ||
           sparam == DrawStripGearCloseIconName())
       {
          DrawStripClose();
          ChartRedraw();
          return DrawStripClickFamily();
       }
       // P-DRAW-11: the plate itself is not a control — a tap on it shuts the

      // open popover (the popover owns the next press, BaseKnot parity) and
      // keeps the strip (and its gear) itself. P-DRAW-29: the plate is a
      // FAMILY (9 skin pieces, or the legacy rect) — any of them is the plate.
      if(DrawStripIsBg(sparam))
      {
         //--- P-DRAW-48: the BOARD's own plate is dead space — a near miss between
         //--- two cells (the 8 px gap) landed on the plate's body and shut the whole
         //--- board, which is half of the report «روی رنگ کلیک میکنم بسته میشه».
         //--- Only the STRIP's and the PANEL's plates still shut the popover.
         if(!DrawStripIsBoardPlate(sparam) && s_dsPicker != DSTRIP_PICK_NONE)
         {
            DrawStripClosePicker();
            DrawStripLayout();
            DrawStripPaint();
         }
         return DrawStripClickFamily();
      }
      // P-DRAW-10: a cell answers by BOTH of its names — the button (its control)
      // and the icon label (its face), because MT4 gives the click to whichever
      // screen object sits highest under the cursor.
      for(int i = 0; i < DSTRIP_MAX_SLOTS; i++)
      {          if(sparam == DrawStripObjName(i) || sparam == DrawStripIconName(i) ||
             sparam == DrawStripIconName(i) + "C" || sparam == DrawStripIconName(i) + "S" ||
             sparam == DrawStripIconName(i) + "C2" || sparam == DrawStripIconName(i) + "R")  // P-DRAW-64a2: the BORDER bar
          { DrawStripTap(i, sparam); return DrawStripClickFamily(); }
      }       if(sparam == DrawStripGripName() || sparam == DrawStripGripIconName() ||
          sparam == DrawStripGripIconName() + "C" || sparam == DrawStripBadgeName() ||//--- P-DRAW-83: the head's version chip is chrome on the head's own
      //--- carry (the head's drag is geometric, `DrawStripGripWhich`), never a
      //--- control — and it was not named anywhere, so a press on it fell past
      //--- every branch and out to the CHART. One more no-op, like the mark and
      //--- the title beside it.
          sparam == DrawStripGearHeadName("VB"))
          return DrawStripClickFamily();   // drag / info / tab bed: no tap
      for(int a = 0; a < DSTRIP_ACT_N; a++)
      {
         if(sparam == DrawStripActName(a) || sparam == DrawStripActIconName(a) ||
            sparam == DrawStripActIconName(a) + "C")
         { DrawStripActTap(a); return DrawStripClickFamily(); }
      }
       // popover header close seat.
       if(sparam == "PnlDrawS_PHeadX")
       {
          DrawStripClosePicker();
          DrawStripLayout();
          DrawStripPaint();
          return DrawStripClickFamily();
       }
       //--- P-PAL-21 (2026-10-02) — THE BOARD'S OWN CONTROLS ARE GONE WITH THE BOARD.
       //--- Its header named the two roles, its band held the RECENT cells, it had a
       //--- HEX field to focus and a pin to dock it to the strip. Every one of those
       //--- was a branch that could only fire while a colour seat was the picker, and
       //--- a colour seat cannot be the picker since P-PAL-19 (the quick row's colour
       //--- cell asks the CARDS' palette instead). The role switch now lives where the
       //--- role is: the two bars on the cell, and the popup's two named chips
       //--- (P-DRAW-64a2).
       // popover rows (button, face, label — one tap).
      for(int r = 0; r < DSTRIP_PICK_MAX; r++)
      {
          if(sparam == DrawStripPickName(r) || sparam == DrawStripPickIconName(r) ||
             sparam == DrawStripPickLabelName(r) || sparam == DrawStripPickChipName(r) ||
             sparam == DrawStripPickRailName(r) || sparam == DrawStripPickGlassName(r))

         { DrawStripPickTap(r); return DrawStripClickFamily(); }
      }
      // gear grid cells, rows, foot. Edits take focus for typing.
      //--- P-DRAW-117 (2026-10-01): THE TAB LOOP IS GONE WITH THE TAB ROW. A group
      //--- header is a ROW (`DSTRIP_GRK_GROUP`), and the row loop below answers it
      //--- through `DrawStripRowName(r)` — the same seat array the paint writes, which
      //--- is the coordinate channel's own rule (P-DRAW-84). The retired `GT*` /
      //--- `GTrack` / `GU` names have no branch here on purpose: no painter in this
      //--- build produces them, and the panel's own paint and purge sweep them.
      for(int g = 0; g < DSTRIP_GRID_MAX; g++)
         if(sparam == DrawStripGridName(g) || sparam == DrawStripGridIconName(g) ||
            sparam == DrawStripGridGlassName(g))
         { DrawStripGridTap(g); return DrawStripClickFamily(); }
      for(int gr = 0; gr < DSTRIP_GLIST_MAX; gr++)
          if(sparam == DrawStripRowName(gr) || sparam == DrawStripRowIconName(gr) ||
             sparam == DrawStripRowLabelName(gr) || sparam == DrawStripRowChipName(gr) ||
             sparam == DrawStripRowRailName(gr) || sparam == DrawStripRowStateName(gr))
         { DrawStripGearRowTap(gr); return DrawStripClickFamily(); }   // P-DRAW-69: the row's private separator is gone
       //--- P-DRAW-83: AND THE FOOT'S OWN GLYPH. `DrawStripFootGlyphName(f)` (the
       //--- 15x15 icon the cards' foot wears at `bx+12`, one `DrawStripFace` above the
       //--- button on Z_STRIP_OVER) was the one member of the foot family the router
       //--- did not answer: a press on the icon itself — the part of a ghost button a
       //--- hand aims at — was the topmost object under the pointer and reached no
       //--- branch at all.
       for(int f = 0; f < DSTRIP_GEAR_FOOT_N; f++)
           if(sparam == DrawStripFootName(f) || sparam == DrawStripFootSkinName(f) ||
              sparam == DrawStripFootGlyphName(f) || sparam == DrawStripFootLabelName(f))
          { DrawStripFootTap(f); return DrawStripClickFamily(); }

      for(int e = 0; e < 5; e++)
         if(sparam == DrawStripEditName(e)) return DrawStripClickFamily();
   }
   // P-DRAW-08f: the drawing was deleted from the TERMINAL's own menu (or by the
   // ✕ of another tool). The paint would notice it on the next click, but a
   // toolbar left floating over nothing is exactly the untidy state the user
   // sees first — so the delete closes it in its own event.
   if(id == CHARTEVENT_OBJECT_DELETE)
   {
      if(sparam == s_dsObj) { Print("[drawstrip] close: OBJECT_DELETE of \"", sparam, "\""); DrawStripClose(); }
      // A deleted CHILD is its parent's business: drop the child, heal parent.
      if(BoxIsMidChild(sparam)) { string par = BoxMidParent(sparam); if(par != "" && ObjectFind(0, par) >= 0) BoxMidSync(par); return false; }
      if(FillIsChild(sparam)) { string fpar = FillChildParent(sparam); if(fpar != "" && ObjectFind(0, fpar) >= 0) FillChildSync(fpar); return false; }
      //--- P-DEL-ALL (2026-10-03) — EVERYTHING A DRAWING OWNS DIES WITH IT. The
      //--- bin paths already drop each family; a NATIVE delete (Delete key, object
      //--- list) fires this event instead and must do the same, or strays stay on
      //--- the chart over the next drawing. Every drop below is name-keyed and a
      //--- no-op when absent; the indicator's own objects never carry FibPen
      //--- children (the sync refuses them outright), and rays/paths are healed
      //--- by their own tools (P-HR-01, PathTool:833) — never a second owner here.
      bool casc = false;
      if(!DrawIsIndicatorObject(sparam))
      {
         if(FibPenStraysDrop(sparam)) casc = true;
         if(FibPenTagDrop(sparam)) casc = true;
         if(FibPenLookDrop(sparam)) casc = true;
      }
      BoxEdgeForget(sparam);
      BoxMidDrop(sparam);
      if(FillChildDrop(sparam)) casc = true;
      BoxMarkDrop(sparam);   // P-UI-134: a deleted box's KEY goes with it
      // P-DEL-NOWb: one flush for every HAND delete, family or not. Our own
      // bulk paths arm the suppression window (their repaint is owned
      // elsewhere); an unsuppressed delete is the user's hand, and under a
      // thousand objects the terminal's own repaint lags a tick behind.
      // P-PERF-DSH1 (2026-10-12): indicator-owned objects are NEVER user
      // gestures — the indicator is the only writer and it owns the repaint.
      // Treating their delete as a "HAND" delete caused DELFLUSH + ChartRedraw
      // per object during bulk sweeps (SweepForeignLadderObjects, CleanupSurplus,
      // DeleteAllIndicatorObjects), accumulating to the measured 4-7 second menu
      // stall. The suppression flag was already supposed to catch this but the
      // 250ms window expired before the terminal delivered all the queued
      // CHARTEVENT_OBJECT_DELETE events (deleting 777 objects takes ~7s).
      // Indicator objects are identified by name prefix (DrawIsIndicatorObject)
      // — a prefix check is O(n) on the prefix length, free compared to the
      // ChartRedraw it replaces.
      bool isOurObject = DrawIsIndicatorObject(sparam);
      bool userDel = !isOurObject && !g_suppressDeleteEvents && !TickDeadlinePending(g_suppressDeleteEventsUntilMs);
      if(casc) DrawStripDiagEmit("[drawstrip] CASCADE obj=\"" + sparam + "\"");
      if(!casc && userDel) DrawStripDiagEmit("[drawstrip] DELFLUSH obj=\"" + sparam + "\"");
      //--- P-DEL-NOW: a native delete drops the family in THIS event, so it owns
      //--- this frame too — without it the strays leave the object list at once
      //--- but their pixels wait for the next tick/pass («وابستگی دیر حذف میشه»).
      if(casc || userDel) ChartRedraw();
      return false;
   }
   // P-DRAW-41 (2026-09-25) — THIS CHANNEL USED TO FOLLOW. P-DRAW-08c/08e/09d made
   // the drag and the chart change re-anchor the plate onto the object's own anchor
   // (throttled to a live-drag cadence), which is exactly how the strip came to sit
    // on the drawing it serves: the plate chased the work into the work. The home is
    // the answer — the plate stays where the user put it.
    if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_CHART_CHANGE)
    {
       // P-DRAW-64d: the mid's own ride left this branch for the router's head (it
       // must follow with the strip SHUT, and this whole channel returns below it),
       // and the interior's never lived here (addendum 4/5). All this channel still
       // owes is the window's clamp (compare-only when kept).
       // Nothing open: this channel has no work at all — and no "object gone" line
       // for a strip that was never there.
       if(s_dsObj == "") return false;

      if(ObjectFind(0, s_dsObj) < 0)
      { Print("[drawstrip] close: object gone on drag/zoom \"", s_dsObj, "\""); DrawStripClose(); return false; }
      // P-DRAW-41 (2026-09-25): NO RE-ANCHOR, and no re-open either. The plate has a
      // home, so a zoom, a scroll or the drawing's own drag moves the WORK and
      // leaves the plate; the strip is already the right picture at the right spot.
      // All this channel still owes is the window's clamp (compare-only when kept).
      DrawStripHomeClamp();
      // P-DRAW-74b-f: a zoom re-measures pixel offsets (scroll is reads-only, the
      // moves compare equal). Served object only — no walks on the scroll path.
      if(id == CHARTEVENT_CHART_CHANGE) FibPenSync(s_dsObj, false);
      return false;
   }
   // P-DRAW-13: the grip carry rides the terminal's own move stream (left = bit 0,
   // BaseKnotTool.mqh:6887 parity). Never consumed: every other half reads moves.
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int st = (int)StringToInteger(sparam);
      DrawStripGripMove((int)lparam, (int)dparam, ((st & 1) != 0));
      // P-DRAGF2: the chase itself moved to the UNGUARDED move branch above — a
      // drawing's followers are not the strip's to carry. This branch keeps the grip
      // carry, which IS the strip's own gesture.
      return false;
   }
    // P-DRAW-13: Esc dismisses inside-out (gear, then popover, then strip — even
    // pinned: Esc is an explicit dismissal, pin only survives outside clicks).
    if(id == CHARTEVENT_KEYDOWN && lparam == 27)
    {
       if(s_dsGear != 0)
      {
         DrawStripGearClose();
         DrawStripLayout();
         DrawStripPaint();
         return true;
      }
      if(s_dsPicker != DSTRIP_PICK_NONE)
      {
         DrawStripClosePicker();
         DrawStripLayout();
         DrawStripPaint();
         return true;
      }
      Print("[drawstrip] close: Esc key");
      DrawStripClose();
      ChartRedraw();
      return true;
   }
   // P-DRAW-13: gear edits commit on Enter (ENDEDIT).
   //--- P-PAL-21: the board's HEX field went with the board, so `DrawStripPopHexEnd`
   //--- is gone — and the note that follows it (P-DRAW-48) stays, because it is the
   //--- reason this branch is a branch and not a bare line: the gear's five edit
   //--- fields are ENDEDIT's only owners here.
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
    {
       for(int e = 0; e < 5; e++)
          if(sparam == DrawStripEditName(e)) { DrawStripEditEnd(e); return true; }
       return false;
    }
     if(id == CHARTEVENT_CLICK)
     {
        int rcx = (int)lparam, rcy = (int)dparam;
        //--- P-DRAW-97 (2026-09-30) — THE SCRUB'S RELEASE, ON THE ONLY CHANNEL THAT
        //--- CARRIES IT. A press on a swatch starts the preview on the press EDGE
        //--- (DrawStripGripMove:40-48) and a MOTIONLESS release emits no MOUSE_MOVE
        //--- — the very fact the line below was written for (P-LM-13) — so the one
        //--- event that ends the gesture is this one, and it reached only
        //--- DrawStripGripRelease, which clears `s_dsPalGrab` and nothing else. The
        //--- drawing therefore kept the PREVIEW's pixels: `DrawSlotPreviewColor`
        //--- writes `OBJPROP_COLOR` (Toolbar_A) and NOT the pure tag its own
        //--- property is read from, so the shape wore a colour its tags did not
        //--- name. Measured consequence of one press-and-lift on a swatch: the swatch
        //--- stayed rimmed in the accent, the colour cell and every `PickIsCur` ring
        //--- kept showing the OLD colour, and no undo step existed for the change.
        //--- P-PAL-21: the scrub's own release (`DrawStripPalRelease`) went with the
        //--- board — the one scrub left is the grip carry, which `DrawStripGripRelease`
        //--- is, and which is asked on the line below as it always was.
        DrawStripGripRelease();   // motionless releases emit no MOVE (P-LM-13 net)
        // P-UI-113i: THE RELEASE'S OWN DRAWING IS NEVER AN OUTSIDE CLICK. The press

       // owner is accepted even if the terminal's control shifts under the hand,
       // and the release pixel gets the same body/control hit test as a still press.
       // Selection is not consulted here: selected and unselected drawings therefore
       // cannot take different paths through dismissal (P-UI-113h's selected handle
       // is geometry, not a special privilege).
       if(DrawStripReleaseOnDrawing(relPressObj, rcx, rcy)) return false;
      // P-DRAW-13: pin survives outside clicks (only ✕ paths, Del and Esc dismiss).
      if(s_dsPinned) return false;
      // P-UI-113d: A DRAG-RELEASE IS NOT A DISMISSAL (the box mini-strip's own
      // `dragRel` / BK_CLICK_SLOP rule, measured in the click head above). Reading
      // it as one is the second way a strip vanished on the user's own hand: hold
      // on a drawing, the strip appears, the hand drifts two digits, let go — and
      // the toolbar they were reaching for is gone.
      if(relWasDrag) return false;
      //--- P-PAL-20 — THE WITNESS, BECAUSE WORKING IS SILENT. This dismissal used to
      //--- be the death of a colour pick («یک رنگ انتخاب می‌کنم کل استریپ بسته می‌شه»):
      //--- the popup the strip itself opened is not the plate, so `PointInside` read
      //--- false on the release pixel over it. Now the ledger answers, and a release
      //--- it catches says so ONCE, through the flushed channel (never `Print` —
      //--- P-LOG-3): `kept=` is the proof the strip survived its own popup.
      int ownedPop = (int)DrawStripSurfaceAt(rcx, rcy);
      if(!DrawStripPointInside(rcx, rcy))
      {
         // DIAG-113 (temporary): one line per dismissal so the log names the
         // gesture that closed the strip, not a guess about it.
         Print("[drawstrip] dismiss click at ", rcx, ",", rcy, " travel=", s_dsTravel,
               " obj=\"", s_dsObj, "\"");
         DrawStripClose();
      }
      else if(ownedPop == 1)
         DrawStripDiagEmit("[drawstrip] SURFHIT release kept the strip at " + IntegerToString(rcx)
                          + "," + IntegerToString(rcy) + " ledger=" + IntegerToString(s_dsSurfN)
                          + " obj=\"" + s_dsObj + "\"");
   }
   return false;
}

#endif // DRAW_STRIP_ROUTER_MQH

#endif // DRAW_STRIP_MQH
