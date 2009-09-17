/*******************************************************************************

    Module with constants needed for text trimming and parsing
    
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Mar 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai

    --

    Usage:
    
    ---
    
        import TextUtil = tango.text.Util: contains;
        import  tango.io.Stdout;
        
        foreach (ref s; this.text)
        {
            if (TextUtil.contains(TextTrimData.CHARS_2STRIP, s) 
            {
                 s = ' ';
            }    
        }
     
        // Print all characters on console with hex code 
        Stdout.format("\n");        
        uint i=0;    
        foreach (c; TextTrimData.CHARS_2STRIP)
        { 
            i++;            
            if ((i%10)==0) Stdout.formatln("");
            Stdout.format("{} [0x{:X4}]\t", c, cast(uint)c);        
        }    
        Stdout.format("\n");        
    }
    
    --

    Additional information:
    
    http://www.fileformat.info/info/unicode/block/index.htm 
    http://www.fileformat.info/info/unicode/block/currency_symbols/utf8test.htm
    http://www.utf8-zeichentabelle.de/unicode-utf8-table.pl?number=1024&htmlent=1
    http://home.tiscali.nl/t876506/utf8tbl.html
    http://www.unicode.org/charts/
       
       
       
*******************************************************************************/

module      ocean.text.TextTrimData;



struct TextTrimData 
{ 
    /**
     * Unicode table with unnesseccary chars
     */
    const   dchar[] CHARS_2STRIP    = [ 
        0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 
        0x0029, 0x002A, 0x002B, 0x002C, 0x002E, 0x002F, 0x002F, 0x003A, 
        0x003B, 0x003C, 0x003D, 0x003E, 0x003F, 0x0040, 0x005B, 0x005C, 
        0x005D, 0x005E, 0x005F, 0x0060, 0x0060, 0x007B, 0x007C, 0x007D, 
        0x007E, 0x00A0, 0x00A1, 0x00A1, 0x00A2, 0x00A2, 0x00A3, 0x00A3, 
        0x00A4, 0x00A5, 0x00A5, 0x00A6, 0x00A7, 0x00A7, 0x00A8, 0x00A8, 
        0x00A9, 0x00A9, 0x00AA, 0x00AA, 0x00AB, 0x00AB, 0x00AC, 0x00AC, 
        0x00AD, 0x00AE, 0x00AE, 0x00AF, 0x00AF, 0x00B0, 0x00B1, 0x00B1, 
        0x00B2, 0x00B3, 0x00B4, 0x00B4, 0x00B5, 0x00B5, 0x00B6, 0x00B6, 
        0x00B7, 0x00B7, 0x00B8, 0x00B8, 0x00B9, 0x00BA, 0x00BA, 0x00BB, 
        0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x00BF, 0x00BF, 0x00C0,        
        0x00D7, 0x00F7, 0x0192, 0x02B0, 0x02B1, 
        0x02B2, 0x02B3, 0x02B4, 0x02B5, 0x02B6, 0x02B7, 0x02B8, 0x02B9, 
        0x02BA, 0x02BB, 0x02C0, 0x02C1, 0x02C2, 0x02C3, 0x02C4, 0x02C5, 
        0x02C6, 0x02C6, 0x02C7, 0x02C7, 0x02C8, 0x02CA, 0x02CB, 0x02CC,
        0x02CE, 0x02CF, 0x02D0, 0x02D1, 0x02D2, 0x02D3, 0x02D4, 0x02D5, 
        0x02D6, 0x02D7, 0x02D8, 0x02D8, 0x02D9, 0x02D9, 0x02DA, 0x02DB, 
        0x02DB, 0x02DC, 0x02DC, 0x02DD, 0x02DD, 0x02DF, 0x02E0, 0x02E1, 
        0x02E2, 0x02E3, 0x02E4, 0x02E5, 0x02E6, 0x02E7, 0x02E8, 0x02E9, 
        0x02EA, 0x02EB, 0x02EC, 0x02ED, 0x02EE, 0x02EF, 0x02F0, 0x02F1, 
        0x02F2, 0x02F3, 0x02F4, 0x02F5, 0x02F6, 0x02F7, 0x02F8, 0x02F9, 
        0x02FA, 0x02FB, 0x02FC, 0x02FD, 0x02FE, 0x02FF, 0x0302, 0x0303, 
        0x0305, 0x0306, 0x0307, 0x0308, 0x030A, 0x030B, 0x030C, 0x030D, 
        0x030E, 0x030F, 0x03A9, 0x03C0, 0x2013, 0x2014, 0x2018, 0x2019, 
        0x201A, 0x201C, 0x201D, 0x201E, 0x201E, 0x201E, 0x2020, 0x2021, 
        0x2022, 0x2026, 0x2030, 0x2039, 0x203A, 0x2044, 0x20A0, 0x20A1, 
        0x20A2, 0x20A3, 0x20A4, 0x20A5, 0x20A6, 0x20A7, 0x20A8, 0x20A9, 
        0x20AA, 0x20AB, 0x20AC, 0x20AC, 0x20AD, 0x20AE, 0x20AF, 0x20B0, 
        0x20B1, 0x20B2, 0x20B3, 0x20B4, 0x20B5, 0x20B6, 0x20B7, 0x20B8, 
        0x20B9, 0x20BA, 0x20BB, 0x20BC, 0x20BD, 0x20BE, 0x20BF, 0x20C1, 
        0x20C2, 0x20C3, 0x20C4, 0x20C5, 0x20C6, 0x20C7, 0x20C8, 0x20C9, 
        0x20CA, 0x20CB, 0x20CC, 0x20CD, 0x20CE, 0x20CF, 0x2122, 0x2202, 
        0x2206, 0x220F, 0x2211, 0x221A, 0x221E, 0x222B, 0x2248, 0x2260, 
        0x2264, 0x2265, 0x25CA, 0xF8FF, 0xFB01, 0xFB02];
    
    
    const   dchar[] ACCENT_CHARS    = [
        0x00C0, 0x00C1, 0x00C2, 0x00C3, 0x00C4, 0x00C5, 0x00C6, 0x00C7, 
        0x00C8, 0x00C9, 0x00CA, 0x00CB, 0x00CC, 0x00CD, 0x00CE, 0x00CF, 
        0x00D1, 0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x00D6, 0x00D8, 0x00D9, 
        0x00DA, 0x00DB, 0x00DC, 0x00DF, 0x00E0, 0x00E1, 0x00E2, 0x00E3, 
        0x00E4, 0x00E5, 0x00E6, 0x00E7, 0x00E8, 0x00E9, 0x00EA, 0x00EB, 
        0x00EC, 0x00ED, 0x00EE, 0x00EF, 0x00F1, 0x00F2, 0x00F3, 0x00F4, 
        0x00F5, 0x00F6, 0x00F8, 0x00F9, 0x00FA, 0x00FB, 0x00FC, 0x00FF, 
        0x0131, 0x0152, 0x0153, 0x0178];
}




/++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

! [0x0021]      " [0x0022]      # [0x0023]      $ [0x0024]      % [0x0025]      & [0x0026]      ' [0x0027]      ( [0x0028]      ) [0x0029]
* [0x002A]      + [0x002B]      , [0x002C]      . [0x002E]      / [0x002F]      / [0x002F]      : [0x003A]      ; [0x003B]      < [0x003C]      = [0x003D]
> [0x003E]      ? [0x003F]      @ [0x0040]      [ [0x005B]      \ [0x005C]      ] [0x005D]      ^ [0x005E]      _ [0x005F]      ` [0x0060]      ` [0x0060]
{ [0x007B]      | [0x007C]      } [0x007D]      ~ [0x007E]        [0x00A0]      ¡ [0x00A1]      ¡ [0x00A1]      ¢ [0x00A2]      ¢ [0x00A2]      £ [0x00A3]
£ [0x00A3]      ¤ [0x00A4]      ¥ [0x00A5]      ¥ [0x00A5]      ¦ [0x00A6]      § [0x00A7]      § [0x00A7]      ¨ [0x00A8]      ¨ [0x00A8]      © [0x00A9]
© [0x00A9]      ª [0x00AA]      ª [0x00AA]      « [0x00AB]      « [0x00AB]      ¬ [0x00AC]      ¬ [0x00AC]      ­ [0x00AD]      ® [0x00AE]      ® [0x00AE]
¯ [0x00AF]      ¯ [0x00AF]      ° [0x00B0]      ± [0x00B1]      ± [0x00B1]      ² [0x00B2]      ³ [0x00B3]      ´ [0x00B4]      ´ [0x00B4]      µ [0x00B5]
µ [0x00B5]      ¶ [0x00B6]      ¶ [0x00B6]      · [0x00B7]      · [0x00B7]      ¸ [0x00B8]      ¸ [0x00B8]      ¹ [0x00B9]      º [0x00BA]      º [0x00BA]
» [0x00BB]      » [0x00BB]      ¼ [0x00BC]      ½ [0x00BD]      ¾ [0x00BE]      ¿ [0x00BF]      ¿ [0x00BF]      À [0x00C0]      Á [0x00C1]      Â [0x00C2]
Ã [0x00C3]      Ä [0x00C4]      Å [0x00C5]      Æ [0x00C6]      Ç [0x00C7]      È [0x00C8]      É [0x00C9]      Ê [0x00CA]      Ë [0x00CB]      Ì [0x00CC]
Í [0x00CD]      Î [0x00CE]      Ï [0x00CF]      Ñ [0x00D1]      Ò [0x00D2]      Ó [0x00D3]      Ô [0x00D4]      Õ [0x00D5]      Ö [0x00D6]      × [0x00D7]
Ø [0x00D8]      Ù [0x00D9]      Ú [0x00DA]      Û [0x00DB]      Ü [0x00DC]      ß [0x00DF]      à [0x00E0]      á [0x00E1]      â [0x00E2]      ã [0x00E3]
ä [0x00E4]      å [0x00E5]      æ [0x00E6]      ç [0x00E7]      è [0x00E8]      é [0x00E9]      ê [0x00EA]      ë [0x00EB]      ì [0x00EC]      í [0x00ED]
î [0x00EE]      ï [0x00EF]      ñ [0x00F1]      ò [0x00F2]      ó [0x00F3]      ô [0x00F4]      õ [0x00F5]      ö [0x00F6]      ÷ [0x00F7]      ÷ [0x00F7]
ø [0x00F8]      ù [0x00F9]      ú [0x00FA]      û [0x00FB]      ü [0x00FC]      ÿ [0x00FF]      ı [0x0131]      Œ [0x0152]      œ [0x0153]      Ÿ [0x0178]
ƒ [0x0192]      ʰ [0x02B0]      ʱ [0x02B1]      ʲ [0x02B2]      ʳ [0x02B3]      ʴ [0x02B4]      ʵ [0x02B5]      ʶ [0x02B6]      ʷ [0x02B7]      ʸ [0x02B8]
ʹ [0x02B9]      ʺ [0x02BA]      ʻ [0x02BB]      ˀ [0x02C0]      ˁ [0x02C1]      ˂ [0x02C2]      ˃ [0x02C3]      ˄ [0x02C4]      ˅ [0x02C5]      ˆ [0x02C6]
ˆ [0x02C6]      ˇ [0x02C7]      ˇ [0x02C7]      ˈ [0x02C8]      ˊ [0x02CA]      ˋ [0x02CB]      ˌ [0x02CC]      ˎ [0x02CE]      ˏ [0x02CF]      ː [0x02D0]
ˑ [0x02D1]      ˒ [0x02D2]      ˓ [0x02D3]      ˔ [0x02D4]      ˕ [0x02D5]      ˖ [0x02D6]      ˗ [0x02D7]      ˘ [0x02D8]      ˘ [0x02D8]      ˙ [0x02D9]
˙ [0x02D9]      ˚ [0x02DA]      ˛ [0x02DB]      ˛ [0x02DB]      ˜ [0x02DC]      ˜ [0x02DC]      ˝ [0x02DD]      ˝ [0x02DD]      ˟ [0x02DF]      ˠ [0x02E0]
ˡ [0x02E1]      ˢ [0x02E2]      ˣ [0x02E3]      ˤ [0x02E4]      ˥ [0x02E5]      ˦ [0x02E6]      ˧ [0x02E7]      ˨ [0x02E8]      ˩ [0x02E9]      ˪ [0x02EA]
˫ [0x02EB]      ˬ [0x02EC]      ˭ [0x02ED]      ˮ [0x02EE]      ˯ [0x02EF]      ˰ [0x02F0]      ˱ [0x02F1]      ˲ [0x02F2]      ˳ [0x02F3]      ˴ [0x02F4]
˵ [0x02F5]      ˶ [0x02F6]      ˷ [0x02F7]      ˸ [0x02F8]      ˹ [0x02F9]      ˺ [0x02FA]      ˻ [0x02FB]      ˼ [0x02FC]      ˽ [0x02FD]      ˾ [0x02FE]
˿ [0x02FF]      ̂ [0x0302]       ̃ [0x0303]       ̅ [0x0305]       ̆ [0x0306]       ̇ [0x0307]       ̈ [0x0308]       ̊ [0x030A]       ̋ [0x030B]       ̌ [0x030C]                                                                                    ̍
 [0x030D]       ̎ [0x030E]       ̏ [0x030F]       Ω [0x03A9]      π [0x03C0]      – [0x2013]      — [0x2014]      ‘ [0x2018]      ’ [0x2019]      ‚ [0x201A]
“ [0x201C]      ” [0x201D]      „ [0x201E]      „ [0x201E]      „ [0x201E]      † [0x2020]      ‡ [0x2021]      • [0x2022]      … [0x2026]      ‰ [0x2030]
‹ [0x2039]      › [0x203A]      ⁄ [0x2044]      ₠ [0x20A0]      ₡ [0x20A1]      ₢ [0x20A2]      ₣ [0x20A3]      ₤ [0x20A4]      ₥ [0x20A5]      ₦ [0x20A6]
₧ [0x20A7]      ₨ [0x20A8]      ₩ [0x20A9]      ₪ [0x20AA]      ₫ [0x20AB]      € [0x20AC]      € [0x20AC]      ₭ [0x20AD]      ₮ [0x20AE]      ₯ [0x20AF]
₰ [0x20B0]      ₱ [0x20B1]      ₲ [0x20B2]      ₳ [0x20B3]      ₴ [0x20B4]      ₵ [0x20B5]      ₶ [0x20B6]      ₷ [0x20B7]      ₸ [0x20B8]      ₹ [0x20B9]
₺ [0x20BA]      ₻ [0x20BB]      ₼ [0x20BC]      ₽ [0x20BD]      ₾ [0x20BE]      ₿ [0x20BF]      ⃁ [0x20C1]      ⃂ [0x20C2]      ⃃ [0x20C3]      ⃄ [0x20C4]
⃅ [0x20C5]      ⃆ [0x20C6]      ⃇ [0x20C7]      ⃈ [0x20C8]      ⃉ [0x20C9]      ⃊ [0x20CA]      ⃋ [0x20CB]      ⃌ [0x20CC]      ⃍ [0x20CD]      ⃎ [0x20CE]
⃏ [0x20CF]      ™ [0x2122]      ∂ [0x2202]      ∆ [0x2206]      ∏ [0x220F]      ∑ [0x2211]      √ [0x221A]      ∞ [0x221E]      ∫ [0x222B]      ≈ [0x2248]
≠ [0x2260]      ≤ [0x2264]      ≥ [0x2265]      ◊ [0x25CA]       [0xF8FF]      ﬁ [0xFB01]      ﬂ [0xFB02]





++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++/