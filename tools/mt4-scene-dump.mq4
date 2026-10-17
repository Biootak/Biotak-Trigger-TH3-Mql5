//+------------------------------------------------------------------+
//| mt4-scene-dump.mq4 - BTRS scene-diff companion (R-RENDER-ENGINE)  |
//|                                                                  |
//|  Writes every level-family HLINE and TEXT object on the MT4 chart |
//|  to MQL4\Files\BTRS_scene_MT4.csv, in the same row schema the MT5 |
//|  engine dump (RBridgeDumpCsv, BTRS_SCENE_DUMP) writes:            |
//|     type;name;price;color;style;width;size;font;text              |
//|  (L = line: style/width filled; T = text: size/font/text filled;  |
//|  color both, 0xRRGGBB.) tools/parity/scene-diff.py matches the    |
//|  two files by name and reports holes and field mismatches.        |
//|                                                                  |
//|  Run it by dragging the compiled script onto the MT4 chart whose  |
//|  indicator settings mirror the MT5 chart under test. The row set  |
//|  is what the object path DREW in the last render pass; give the   |
//|  terminal a settled second before running.                        |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

input string FilterPrefix = "THLevels_";  // level family prefix (inpObjectPrefix + "_")

void OnStart()
{
   int h = FileOpen("BTRS_scene_MT4.csv", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      Alert("BTRS dump: cannot open BTRS_scene_MT4.csv (err ", GetLastError(), ")");
      return;
   }
   FileWriteString(h, "type;name;price;color;style;width;size;font;text\r\n");

   int nl = 0, nt = 0;
   int total = ObjectsTotal();
   for(int i = 0; i < total; i++)
   {
      string nm = ObjectName(i);
      if(StringFind(nm, FilterPrefix) != 0) continue;   // the level family only

      int type = ObjectType(nm);
      if(type == OBJ_HLINE)
      {
         FileWriteString(h, StringFormat("L;%s;%.8f;0x%06X;%d;%d;;;\r\n",
            nm, ObjectGet(nm, OBJPROP_PRICE1),
            ((int)ObjectGet(nm, OBJPROP_COLOR)) & 0x00FFFFFF,
            (int)ObjectGet(nm, OBJPROP_STYLE),
            (int)ObjectGet(nm, OBJPROP_WIDTH)));
         nl++;
      }
      else if(type == OBJ_TEXT)
      {
         FileWriteString(h, StringFormat("T;%s;%.8f;0x%06X;;;%d;%s;%s\r\n",
            nm, ObjectGet(nm, OBJPROP_PRICE1),
            ((int)ObjectGet(nm, OBJPROP_COLOR)) & 0x00FFFFFF,
            (int)ObjectGet(nm, OBJPROP_FONTSIZE),
            ObjectGetString(0, nm, OBJPROP_FONT, 0),
            ObjectGetString(0, nm, OBJPROP_TEXT, 0)));
         nt++;
      }
   }
   FileClose(h);
   Print("BTRS dump: ", nl, " lines + ", nt, " texts -> MQL4\\Files\\BTRS_scene_MT4.csv");
}
//+------------------------------------------------------------------+
