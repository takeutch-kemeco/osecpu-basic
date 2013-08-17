dim scw; scw:=480; dim sch; sch:=240
dim pool(1000); dim m(3,3); dim v(3); dim rd; rd:=3.14159265358979/180;
dim vt(8); vt(0):=100>>16; vt(1):=104>>16; vt(2):=108>>16; vt(3):=112>>16;
           vt(4):=116>>16; vt(5):=120>>16; vt(6):=124>>16; vt(7):=128>>16;
dim vtx(8); vtx(0):=160>>16; vtx(1):=164>>16; vtx(2):=168>>16; vtx(3):=172>>16;
            vtx(4):=176>>16; vtx(5):=180>>16; vtx(6):=184>>16; vtx(7):=188>>16;
dim rm(5); rm(0):=200>>16; rm(1):=220>>16; rm(2):=240>>16; rm(3):=260>>16; rm(4):=280>>16;
dim rv(3); rv(0):=0; rv(1):=0; rv(2):=0;
dim rvd(3); rvd(0):=rd*0.5; rvd(1):=rd*1.0; rvd(2):=rd*1.5;
vt(0)<-v(0):=-22; vt(0)<-v(1):=-22; vt(0)<-v(2):=-22; vt(1)<-v(0):=+22; vt(1)<-v(1):=-22; vt(1)<-v(2):=-22;
vt(2)<-v(0):=+22; vt(2)<-v(1):=+22; vt(2)<-v(2):=-22; vt(3)<-v(0):=-22; vt(3)<-v(1):=+22; vt(3)<-v(2):=-22;
vt(4)<-v(0):=-22; vt(4)<-v(1):=-22; vt(4)<-v(2):=+22; vt(5)<-v(0):=+22; vt(5)<-v(1):=-22; vt(5)<-v(2):=+22;
vt(6)<-v(0):=+22; vt(6)<-v(1):=+22; vt(6)<-v(2):=+22; vt(7)<-v(0):=-22; vt(7)<-v(1):=+22; vt(7)<-v(2):=+22;

openwin scw sch

*LLL
        mat rv := rv + rvd

        dim rs; dim rc;
        mat rm(0)<-m:=idn; rs:=sin rv(0); rc:=cos rv(0); rm(0)<-m(1,1):=rc; rm(0)<-m(1,2):=-rs; rm(0)<-m(2,1):= rs; rm(0)<-m(2,2):=rc;
        mat rm(1)<-m:=idn; rs:=sin rv(1); rc:=cos rv(1); rm(1)<-m(0,0):=rc; rm(1)<-m(0,2):= rs; rm(1)<-m(2,0):=-rs; rm(1)<-m(2,2):=rc;
        mat rm(2)<-m:=idn; rs:=sin rv(2); rc:=cos rv(2); rm(2)<-m(0,0):=rc; rm(2)<-m(0,1):=-rs; rm(2)<-m(1,0):= rs; rm(2)<-m(1,1):=rc;

        mat rm(3)<-m:=rm(0)<-m * rm(1)<-m; mat rm(4)<-m:=rm(3)<-m * rm(2)<-m;

        mat vtx(0)<-v:=rm(4)<-m * vt(0)<-v; mat vtx(1)<-v:=rm(4)<-m * vt(1)<-v;
        mat vtx(2)<-v:=rm(4)<-m * vt(2)<-v; mat vtx(3)<-v:=rm(4)<-m * vt(3)<-v;
        mat vtx(4)<-v:=rm(4)<-m * vt(4)<-v; mat vtx(5)<-v:=rm(4)<-m * vt(5)<-v;
        mat vtx(6)<-v:=rm(4)<-m * vt(6)<-v; mat vtx(7)<-v:=rm(4)<-m * vt(7)<-v;

        dim prj; prj:=200; dim tz; tz:=100; dim iz;
        iz:=(vtx(0)<-v(2) + tz); vtx(0)<-v(0):=(vtx(0)<-v(0) * prj)/iz; vtx(0)<-v(1):=(vtx(0)<-v(1) * prj)/iz;
        iz:=(vtx(1)<-v(2) + tz); vtx(1)<-v(0):=(vtx(1)<-v(0) * prj)/iz; vtx(1)<-v(1):=(vtx(1)<-v(1) * prj)/iz;
        iz:=(vtx(2)<-v(2) + tz); vtx(2)<-v(0):=(vtx(2)<-v(0) * prj)/iz; vtx(2)<-v(1):=(vtx(2)<-v(1) * prj)/iz;
        iz:=(vtx(3)<-v(2) + tz); vtx(3)<-v(0):=(vtx(3)<-v(0) * prj)/iz; vtx(3)<-v(1):=(vtx(3)<-v(1) * prj)/iz;
        iz:=(vtx(4)<-v(2) + tz); vtx(4)<-v(0):=(vtx(4)<-v(0) * prj)/iz; vtx(4)<-v(1):=(vtx(4)<-v(1) * prj)/iz;
        iz:=(vtx(5)<-v(2) + tz); vtx(5)<-v(0):=(vtx(5)<-v(0) * prj)/iz; vtx(5)<-v(1):=(vtx(5)<-v(1) * prj)/iz;
        iz:=(vtx(6)<-v(2) + tz); vtx(6)<-v(0):=(vtx(6)<-v(0) * prj)/iz; vtx(6)<-v(1):=(vtx(6)<-v(1) * prj)/iz;
        iz:=(vtx(7)<-v(2) + tz); vtx(7)<-v(0):=(vtx(7)<-v(0) * prj)/iz; vtx(7)<-v(1):=(vtx(7)<-v(1) * prj)/iz;

        dim ov(3); ov(0):=scw/2; ov(1):=sch/2; ov(2):=0;
        mat vtx(0)<-v:=vtx(0)<-v+ov; mat vtx(1)<-v:=vtx(1)<-v+ov; mat vtx(2)<-v:=vtx(2)<-v+ov; mat vtx(3)<-v:=vtx(3)<-v+ov;
        mat vtx(4)<-v:=vtx(4)<-v+ov; mat vtx(5)<-v:=vtx(5)<-v+ov; mat vtx(6)<-v:=vtx(6)<-v+ov; mat vtx(7)<-v:=vtx(7)<-v+ov;

        drawline 0 vtx(0)<-v(0) vtx(0)<-v(1) vtx(1)<-v(0) vtx(1)<-v(1) 255 255 255
        drawline 0 vtx(1)<-v(0) vtx(1)<-v(1) vtx(2)<-v(0) vtx(2)<-v(1) 255 255 255
        drawline 0 vtx(2)<-v(0) vtx(2)<-v(1) vtx(3)<-v(0) vtx(3)<-v(1) 255 255 255
        drawline 0 vtx(3)<-v(0) vtx(3)<-v(1) vtx(0)<-v(0) vtx(0)<-v(1) 255 255 255

        drawline 0 vtx(4)<-v(0) vtx(4)<-v(1) vtx(5)<-v(0) vtx(5)<-v(1) 255 255 255
        drawline 0 vtx(5)<-v(0) vtx(5)<-v(1) vtx(6)<-v(0) vtx(6)<-v(1) 255 255 255
        drawline 0 vtx(6)<-v(0) vtx(6)<-v(1) vtx(7)<-v(0) vtx(7)<-v(1) 255 255 255
        drawline 0 vtx(7)<-v(0) vtx(7)<-v(1) vtx(4)<-v(0) vtx(4)<-v(1) 255 255 255

        drawline 0 vtx(0)<-v(0) vtx(0)<-v(1) vtx(4)<-v(0) vtx(4)<-v(1) 255 255 255
        drawline 0 vtx(1)<-v(0) vtx(1)<-v(1) vtx(5)<-v(0) vtx(5)<-v(1) 255 255 255
        drawline 0 vtx(2)<-v(0) vtx(2)<-v(1) vtx(6)<-v(0) vtx(6)<-v(1) 255 255 255
        drawline 0 vtx(3)<-v(0) vtx(3)<-v(1) vtx(7)<-v(0) vtx(7)<-v(1) 255 255 255


        sleep 0 16
        fillrect 0  scw sch 0 0 100 140 180
goto *LLL
