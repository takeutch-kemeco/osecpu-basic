openwin 256 256;

dim c;
for (c = 0; c < 1234; c = c + 0.05) {
        dim b = (cos c) * 255;
        if (b < 0)
                b = -b;

        dim h;
        for (h = 0; h < 256; h = h + 1) {
                dim w;
                for (w = 0; w < 256; w = w + 1) {
                        dim col = torgb w h b;
                        dim nul = drawpoint 0 w h col;
                }
        }

        dim nul = sleep 0 16;
}
