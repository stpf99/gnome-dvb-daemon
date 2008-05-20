using GLib;

namespace DVB {

    private static const string RESERVED = "reserved";

    public static class Utils {

        public static string reencode_string (string text) {
            if (text == "") return text;
            
            uint start_text;
            string encoding;
            int firstbyte = (int)text[0];
            
            debug ("First byte is 0x%x", firstbyte);
            if (firstbyte == 0x01) {
                encoding = "iso8859-5";
                start_text = 1;
            } else if (firstbyte == 0x02) {
                encoding = "iso8859-6";
                start_text = 1;
            } else if (firstbyte == 0x03) {
                encoding = "iso8859-7";
                start_text = 1;
            } else if (firstbyte == 0x04) {
                encoding = "iso8859-8";
                start_text = 1;
            } else if (firstbyte == 0x05) {
                encoding = "iso8859-9";
                start_text = 1;
            } else if (firstbyte >= 0x20 && firstbyte <= 0xff) {
                encoding = "iso8859-1";
                start_text = 0;
            } else if (firstbyte == 0x10) {
                encoding = "iso8859-";
                //table = struct.unpack("H", t[1:3])[0]
                //encoding += str(log(table, 2));
                start_text = 3;
            } else if (firstbyte == 0x11) {
                encoding = "utf16";
                start_text = 1;
            } else {
                encoding = RESERVED;
            }
            
            debug ("Detected encoding %s\n", encoding);
            
            if (encoding == RESERVED) {
                warning("Unsupported encoding");
                return text;
            }
            
            StringBuilder sb = new StringBuilder.sized(text.size());
            uint i;
            for (i=start_text; i<text.size(); i++) {
                unichar thischar = text[i];
                if ((int)thischar == 0x86) {
                    sb.append ("<b>");
                } else if ((int)thischar == 0x87) {
                    sb.append ("</b>");
                } else if ((int)thischar == 0x8a) {
                    sb.append ("\n");
                } else {
                    sb.append_unichar (thischar);
                }
            }

            try {
                return convert (sb.str, sb.len, "utf8", encoding);
            } catch (ConvertError e) {
                error(e.message);
                return text;
            }
        }
    }

}
