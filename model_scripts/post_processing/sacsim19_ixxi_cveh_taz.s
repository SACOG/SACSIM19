
RUN PGM=MATRIX  MSG='convert parcel txt into dbf'

FILEI RECI = ?_raw_parcel.txt,delimiter[1]=','

FILEO reco[1] = ?_raw_parcel.dbf,
    fields=parcelid(12.0),taz(5.0),hh_p(10.5),empfoo_p(10.5),empret_p(10.5),empsvc_p(10.5),emptot_p(10.5)

if (reci.recno=1)
    loop f=1, reci.numfields
        if (reci.cfield[f]='parcelid')       f_parcelid       = f
        if (reci.cfield[f]='taz_p')  f_taz_p  = f
        if (reci.cfield[f]='hh_p')  f_hh_p  = f
        if (reci.cfield[f]='empfoo_p')     f_empfoo_p       = f
        if (reci.cfield[f]='empret_p')      f_empret_p       = f
        if (reci.cfield[f]='empsvc_p')      f_empsvc_P      = f
        if (reci.cfield[f]='emptot_p')      f_emptot_p     = f
    endloop
 
ELSE
       ro.parcelid  = val(reci.cfield[f_parcelid])    
       ro.taz  = val(reci.cfield[f_taz_p])  
       ro.hh_p  = val(reci.cfield[f_hh_p])  
       ro.empfoo_p  = val(reci.cfield[f_empfoo_p])      
       ro.empret_p  = val(reci.cfield[f_empret_p])    
       ro.empsvc_p   = val(reci.cfield[f_empsvc_p])   
       ro.emptot_p  = val(reci.cfield[f_emptot_P])  
    
    WRITE reco=1

ENDIF

ENDRUN


;======================================================================

run pgm=matrix  msg='compile ix+xi person and vehicle trips, miles, c-miles'
; compile ix+xi (basically, any trip from the external matrix for regional indicators
; 
; Input files: 
filei mati[1]="trips.external.mat"
      mati[2]="tempskh07.mat"
      mati[3]="tempskmd5.mat"
      mati[4]="tempskh16.mat"
      mati[5]="tempskev2.mat"
; main output is a matrix w/ all variables combined for calculations...
mato[1]="ixxi_temp.mat", mo=5-13 name=x_vt,x_vht,x_vmt,x_cvmt,hhs,emptot,food,ret,svc
; initialize p-a person trips by purpose
;
zdati[2] = ?_raw_parcel.dbf, 
sum=hh_p,
    EMPFOO_P,
    EMPRET_P,
    EMPSVC_P,
    EMPTOT_P
;
jloop
;
mw[1]=mi.1.xwk
mw[2]=mi.1.xpb
mw[3]=mi.1.xsh
mw[4]=mi.1.xsr
; transposes
mw[28] = mi.1.xwk.t
mw[23] = mi.1.xpb.t
mw[24] = mi.1.xsh.t
mw[25] = mi.1.xsr.t


; A3
; first drive alone
;         share         tot_pa         tot_ap
x_da_a3 = 0.890*(mi.1.xwk*0.295 + mw[28]*0.018)
x_da_a3 = 0.540*(mi.1.xpb*0.088 + mw[23]*0.037) + x_da_a3
x_da_a3 = 0.450*(mi.1.xsh*0.028 + mw[24]*0.027) + x_da_a3
x_da_a3 = 0.290*(mi.1.xsr*0.060 + mw[25]*0.029) + x_da_a3
;
; next shared ride--s2 and s3+ combined...
;          share         tot_pa         tot_ap  vocc
x_sr_a3 = 0.110*(mi.1.xwk*0.295 + mw[28]*0.018)/2.34
x_sr_a3 = 0.460*(mi.1.xpb*0.088 + mw[23]*0.037)/2.55 + x_sr_a3
x_sr_a3 = 0.550*(mi.1.xsh*0.028 + mw[24]*0.027)/2.41 + x_sr_a3
x_sr_a3 = 0.710*(mi.1.xsr*0.060 + mw[25]*0.029)/2.85 + x_sr_a3
;
; MD
; first drive alone
;         share          tot_pa         tot_ap
x_da_md = 0.890*(mi.1.xwk*0.101 + mw[28]*0.098)
x_da_md = 0.540*(mi.1.xpb*0.264 + mw[23]*0.226) + x_da_md
x_da_md = 0.450*(mi.1.xsh*0.231 + mw[24]*0.217) + x_da_md
x_da_md = 0.290*(mi.1.xsr*0.173 + mw[25]*0.149) + x_da_md
;
; next shared ride--s2 and s3+ combined...
;         share          tot_pa         tot_ap  vocc
x_sr_md = 0.110*(mi.1.xwk*0.101 + mw[28]*0.098)/2.34
x_sr_md = 0.460*(mi.1.xpb*0.264 + mw[23]*0.226)/2.55 + x_sr_md
x_sr_md = 0.550*(mi.1.xsh*0.231 + mw[24]*0.217)/2.41 + x_sr_md
x_sr_md = 0.710*(mi.1.xsr*0.173 + mw[25]*0.149)/2.85 + x_sr_md
;
; P3
; first drive alone
;         share          tot_pa         tot_ap
x_da_p3 = 0.890*(mi.1.xwk*0.035 + mw[28]*0.300)
x_da_p3 = 0.540*(mi.1.xpb*0.112 + mw[23]*0.165) + x_da_p3
x_da_p3 = 0.450*(mi.1.xsh*0.181 + mw[24]*0.178) + x_da_p3
x_da_p3 = 0.290*(mi.1.xsr*0.147 + mw[25]*0.117) + x_da_p3
;
; next shared ride--s2 and s3+ combined...
;         share           tot_pa        tot_ap  vocc
x_sr_p3 = 0.110*(mi.1.xwk*0.035 + mw[28]*0.300)/2.34
x_sr_p3 = 0.460*(mi.1.xpb*0.112 + mw[23]*0.165)/2.55 + x_sr_p3
x_sr_p3 = 0.550*(mi.1.xsh*0.181 + mw[24]*0.178)/2.41 + x_sr_p3
x_sr_p3 = 0.710*(mi.1.xsr*0.147 + mw[25]*0.117)/2.85 + x_sr_p3
;
; EV
; first drive alone
;         share          tot_pa         tot_ap
x_da_ev = 0.890*(mi.1.xwk*0.069 + mw[28]*0.084)
x_da_ev = 0.540*(mi.1.xpb*0.036 + mw[23]*0.072) + x_da_ev
x_da_ev = 0.450*(mi.1.xsh*0.060 + mw[24]*0.078) + x_da_ev
x_da_ev = 0.290*(mi.1.xsr*0.120 + mw[25]*0.205) + x_da_ev
;
; next shared ride--s2 and s3+ combined...
;         share          tot_pa         tot_ap  vocc
x_sr_ev = 0.110*(mi.1.xwk*0.069 + mw[28]*0.084)/2.34
x_sr_ev = 0.460*(mi.1.xpb*0.036 + mw[23]*0.072)/2.55
x_sr_ev = 0.550*(mi.1.xsh*0.060 + mw[24]*0.078)/2.41
x_sr_ev = 0.710*(mi.1.xsr*0.120 + mw[25]*0.205)/2.85

;order of calcs as follows:  vts; vht; vmt; cvmt

mw[5]=x_da_a3+x_da_md+x_da_p3+x_da_ev+x_sr_a3+x_sr_md+x_sr_p3+x_sr_ev
mw[6]=(x_da_a3*mi.2.da_time+x_da_md*mi.3.da_time+x_da_p3*mi.4.da_time+x_da_ev*mi.5.da_time+x_sr_a3*(mi.2.s2_time+mi.2.s3_time)*0.5+x_sr_md*mi.3.da_time+x_sr_p3*(mi.4.s2_time+mi.4.s3_time)*0.5+x_sr_ev*mi.5.da_time)/60.0
mw[7]=x_da_a3*mi.2.da_dist+x_da_md*mi.3.da_dist+x_da_p3*mi.4.da_dist+x_da_ev*mi.5.da_dist+x_sr_a3*(mi.2.s2_dist+mi.2.s3_dist)*0.5+x_sr_md*mi.3.da_dist+x_sr_p3*(mi.4.s2_dist+mi.4.s3_dist)*0.5+x_sr_ev*mi.5.da_dist
mw[8]=x_da_a3*mi.2.da_cdist+x_da_md*mi.3.da_cdist+x_da_p3*mi.4.da_cdist+x_da_ev*mi.5.da_cdist+x_sr_a3*(mi.2.s2_cdist+mi.2.s3_cdist)*0.5+x_sr_md*mi.3.da_cdist+x_sr_p3*(mi.4.s2_cdist+mi.4.s3_cdist)*0.5+x_sr_ev*mi.5.da_cdist
;
;mw[9]  = zi.2.housesp / (1+zi.2.housesp + 1.1*(zi.2.emptot_p - zi.2.empfoodp - zi.2.empret_p - 0.25*zi.2.empsvc_p)) ;res share of ixxi
mw[9] = zi.2.hh_p
mw[10] = zi.2.emptot_p
mw[11] = zi.2.empfoo_p
mw[12] = zi.2.empret_p
mw[13] = zi.2.empsvc_p

endjloop
;
endrun

run pgm=matrix
filei mati[1]=trips.cv.mat
      mati[2]="tempskh07.mat"
      mati[3]="tempskmd5.mat"
      mati[4]="tempskh16.mat"
      mati[5]="tempskev2.mat"
FILEO MATO=cv_temp.mat, MO=1-4
;
jloop
;
mw[1]=mi.2.da_dist
mw[2]=mi.3.da_dist
mw[3]=mi.4.da_dist
mw[4]=mi.5.da_dist
mw[5]=mi.2.da_time/60.0
mw[6]=mi.3.da_time/60.0
mw[7]=mi.4.da_time/60.0
mw[8]=mi.5.da_time/60.0
mw[9]=mi.2.da_cdist
mw[10]=mi.3.da_cdist
mw[11]=mi.4.da_cdist
mw[12]=mi.5.da_cdist
mw[13]=mi.1.cv2x
mw[14]=mi.1.cv3x
;
;A3
; calcs 1 and 2=c2vmt,c3vmt; 3 and 4=c2vht, c3vht; 5 and 6 = c2cvmt, c3cvmt
mw[15]=mw[13]*0.224*mw[5] + mw[13]*0.407*mw[6] + mw[13]*0.136*mw[7] + mw[13]*0.208*mw[8]
mw[16]=mw[14]*0.287*mw[5] + mw[14]*0.319*mw[6] + mw[14]*0.089*mw[7] + mw[14]*0.279*mw[8]
;
mw[17]=mw[13]*0.224*mw[1] + mw[13]*0.407*mw[2] + mw[13]*0.136*mw[3] + mw[13]*0.208*mw[4]
mw[18]=mw[14]*0.287*mw[1] + mw[14]*0.319*mw[2] + mw[14]*0.089*mw[3] + mw[14]*0.279*mw[4]
;
mw[19]=mw[13]*0.224*mw[9] + mw[13]*0.407*mw[10] + mw[13]*0.136*mw[11] + mw[13]*0.208*mw[12]
mw[20]=mw[14]*0.287*mw[9] + mw[14]*0.319*mw[10] + mw[14]*0.089*mw[11] + mw[14]*0.279*mw[12]
;
endjloop
;
fileo reco[1]=cveh_taz.dbf, fields=i,c2_vt_i,c3_vt_i,c2_vht_i,c3_vht_i,c2_vmt_i,c3_vmt_i,c2_cvmt_i,c3_cvmt_i
ro.i=i
c2_vt_i=rowsum(13)
c3_vt_i=rowsum(14)
c2_vht_i=rowsum(15)
c3_vht_i=rowsum(16)
c2_vmt_i=rowsum(17)
c3_vmt_i=rowsum(18)
c2_cvmt_i=rowsum(19)
c3_cvmt_i=rowsum(20)
write reco=1
;
endrun
;


;run pgm=matrix
;filei mati[1]=temp.mat
;mw[1]=mi.1.1
;mw[2]=mi.1.2
;mw[3]=mi.1.3
;mw[4]=mi.1.4
;endrun


run pgm=matrix  msg='compile ix+xi person and vehicle trips, miles, c-miles'
; compile ix+xi (basically, any trip from the external matrix for regional indicators
; Input files: 
filei mati[1]="ixxi_temp.mat"
      
; also output a rowsum file in dbf
jloop
mw[1]=mi.1.x_vt
mw[2]=mi.1.x_vht
mw[3]=mi.1.x_vmt
mw[4]=mi.1.x_cvmt
mw[5]=mi.1.x_vt.t
mw[6]=mi.1.x_vht.t
mw[7]=mi.1.x_vmt.t
mw[8]=mi.1.x_cvmt.t
mw[9]=mi.1.hhs
mw[10]=mi.1.emptot
mw[11]=mi.1.food
mw[12]=mi.1.ret
mw[13]=mi.1.svc
;
endjloop
;
fileo reco[1]=ixxi_taz.dbf, fields=i,ix_vt_i,ix_vt_j,ix_vht_i,ix_vht_j,ix_vmt_i,ix_vmt_j,ix_cvmt_i,ix_cvmt_j,hhs,emptot,food,ret,svc
ro.i=i
ix_vt_i=rowsum(1)
ix_vt_j=rowsum(5)
ix_vht_i=rowsum(2)
ix_vht_j=rowsum(6)
ix_vmt_i=rowsum(3)
ix_vmt_j=rowsum(7)
ix_cvmt_i=rowsum(4)
ix_cvmt_j=rowsum(8)
hhs=rowave(9)
emptot=rowave(10)
food=rowave(11)
ret=rowave(12)
svc=rowave(13)
write reco=1
;
endrun

