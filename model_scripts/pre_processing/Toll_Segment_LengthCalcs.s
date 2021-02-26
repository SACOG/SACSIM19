; this block of code calculates the total length of each toll segments, which will later be used to apportion tolls to each link
	AllLaneToll = 0 ;1 True, 0 False. Turn true if all lane toll facilities exist.
	run pgm = hwynet  MSG='step 0 Calculate toll segment length'
 
   neti = ?_base.net
   fileo printo[1] = tollseg_length_inital.csv
  
   array tseg_length = 200
   array nseg_length= 200
   array aseg_length= 200
     
   phase = linkmerge
   
	   loop _segment=1,200
	   
			if (_segment = TOLLID) 	   
			   tseg_length[_segment] = tseg_length[_segment] + li.1.distance
			endif
			if (_segment = GPID) 	   
			   nseg_length[_segment] = nseg_length[_segment] + li.1.distance
			endif
			if (_segment = AUXID) 	   
			   aseg_length[_segment] = aseg_length[_segment] + li.1.distance   
			endif
			if ((_segment = TOLLID) && (_numseg<TOLLID))
				_numseg = TOLLID
			endif

		endloop
		
	
	endphase
	
    phase = summary
	 PRINT CSV=T LIST='tollid,toll_mi,gp_mi,aux_mi' PRINTO=1
	 loop _segment=1,200
	 
		 if (tseg_length[_segment] > 0)
	     		absDiffLen = ABS(tseg_length[_segment] - nseg_length[_segment])
				IF(@AllLaneToll@ > 0)
				  tseg_length[_segment] = nseg_length[_segment] ;set toll segment to GP distance
				  absDIFfLen = ABS(tseg_length[_segment] - nseg_length[_segment])
				ENDIF
				if(absDiffLen > 0.25) exit   ;add an error message here
	
		   PRINT CSV=T LIST=_segment, tseg_length[_segment] , nseg_length[_segment] , aseg_length[_segment] PRINTO=1
		 endif
		
	 endloop
	 
	endphase
	
	LOG PREFIX=network, VAR=_numseg
   
	LOG VAR = _numseg

endrun