RUN PGM=network
filei neti[1]=p140day_4byfy.net
      linki[2]=2016day_4byfy.net
fileo neto=p11640_byfy.net,include=name,distance,screen,rad,hwyseg,sactrak,c08dyd,c12dyd,c16dyd
;first global from fy nw
name=li.1.name
distance=li.1.distance
screen=li.1.screen
rad=li.1.rad
hwyseg=li.1.hwyseg
trav_dir=li.1.trav_dir
fwyid=li.1.fwyid
countid=li.1.countid
sactrak=li.1.sactrak
c08dyd=li.1.c08dyd
c12dyd=li.1.c12dyd
c16dyd=li.1.c16dyd
;initialize all values
;next by link inputs
bylanes=0
fylanes=0
bycapcl=0
fycapcl=0
byspeed=0
fyspeed=0
bybike=0
fybike=0
bycs=0
fycs=0
bylnmi=0
fylnmi=0
bya3v=0
fya3v=0
bymdv=0
fymdv=0
byp3v=0
fyp3v=0
bya3s=0
fya3s=0
bymds=0
fymds=0
byp3s=0
fyp3s=0
byevs=0
fyevs=0
bydyv=0
fydyv=0
bydvmt=0
fydvmt=0
bydcvmt=0
fydcvmt=0
bydvht=0
fydvht=0
bya3vc=0
fya3vc=0
bymdvc=0
fymdvc=0
byp3vc=0
fyp3vc=0
bycongmapvc=0
fycongmapvc=0
bycongmapvol=0
fycongmapvol=0
bycongmapcode=0
fycongmapcode=0
bycvmt_p=0
bycvmt_p=0
fybydyv_p=0
fybylanes=0
proj=0
proj_IN=0
newroad=0
delta_lanes=0
delta_day=0
delta_dvmt=0
delta_dcvmt=0
byrd_util=0
fyrd_util=0

;populate variables
bylanes=li.2.lanes
fylanes=li.1.lanes
bycapcl=li.2.capclass
fycapcl=li.1.capclass
byspeed=li.2.speed
fyspeed=li.2.speed
bybike=li.2.bike
fybike=li.1.bike
bycs=li.2.cs
fycs=li.1.cs
bylnmi=li.2.lanemi
fylnmi=li.1.lanemi
bya3v=li.2.a3v
fya3v=li.1.a3v
bymdv=li.2.mdv
fymdv=li.1.mdv
byp3v=li.2.p3v
fyp3v=li.1.p3v
bya3spd=li.2.a3s
fya3spd=li.1.a3s
bymdspd=li.2.md5s
fymdspd=li.1.md5s
byp3spd=li.2.p3s
fyp3spd=li.1.p3s
byevspd=li.2.evs
fyevspd=li.1.evs
if(c16dyd>0)
   volifcnt=li.2.dyv
endif
bydyv=li.2.dyv
fydyv=li.1.dyv
bydvmt=li.2.dayvmt
fydvmt=li.1.dayvmt
bydcvmt=li.2.daycvmt
fydcvmt=li.1.daycvmt
bydvht=li.2.dayvht
fydvht=li.1.dayvht
bya3vc=li.2.a3vc
fya3vc=li.1.a3vc
byp3vc=li.2.p3vc
fyp3vc=li.1.p3vc
bycongmapvc=bya3vc
if(bya3vc<byp3vc)
   bycongmapvc=byp3vc
endif
fycongmapvc=fya3vc
if(fya3vc<fyp3vc)
   fycongmapvc=fyp3vc
endif
;
if(bydvmt>0)
   bycvmt_p=bydcvmt/bydvmt
endif
if(fydvmt>0)
   bycvmt_p=fydcvmt/fydvmt
endif
if(bydyv>0)
   fybydyv_p=fydyv/bydyv
endif
if(bylanes>0)
   fybylanes=fylanes/bylanes
endif
;
;compute key delta measures
if(fycapcl<99&&bycapcl=99)
   newroad=1  ;new roadways
endif
if(fycapcl=99&&bycapcl<99)
   newroad=2  ;deleted roadways
endif
delta_lanes=fylanes-bylanes
delta_day=fydyv-bydyv
delta_dvmt=fydvmt-bydvmt
delta_dcvmt=fydcvmt-bydcvmt
if(sactrak>' ')
   proj=1
endif
if(delta_lanes>0)
   proj_IN=1
endif
if(fycapcl<>bycapcl)
   proj_IN=1
endif
;roadway utilization
;1=underutilized
;2=well utilized
;3=overutilized
;roadway utilization_by
if(bycapcl=5,24&&bycongmapvc<0.85)
   byrd_util=2
endif
if(bycapcl=5,24&&bycongmapvc>=0.85)
   byrd_util=3
endif
if(bycapcl=2,3,4,12,22&&bycongmapvc<0.85)
   byrd_util=1
endif
if(bycapcl=2,3,4,12,22&&(bycongmapvc>=0.85&&bycongmapvc<=1.1))
   byrd_util=2
endif
if(bycapcl=2,3,4,12,22&&bycongmapvc>1.1)
   byrd_util=3
endif
if(bycapcl=1,6,16,26&&bycongmapvc<0.9)
   byrd_util=1
endif
if(bycapcl=1,6,16,26&&(bycongmapvc>=0.9&&bycongmapvc<=1.05))
   byrd_util=2
endif
if(bycapcl=1,6,16,26&&bycongmapvc>1.05)
   byrd_util=3
endif
if(bycapcl=8,9,51,56&&bycongmapvc<0.5)
   byrd_util=1
endif
if(bycapcl=8,9,51,56&&(bycongmapvc>=0.5&&bycongmapvc<=0.85))
   byrd_util=2
endif
if(bycapcl=8,9,51,56&&bycongmapvc>0.85)
   byrd_util=3
endif
;roadway utilization_fy
if(fycapcl=5,24&&fycongmapvc<0.85)
   fyrd_util=2
endif
if(fycapcl=5,24&&fycongmapvc>=0.85)
   fyrd_util=3
endif
if(fycapcl=2,3,4,12,22&&fycongmapvc<0.85)
   fyrd_util=1
endif
if(fycapcl=2,3,4,12,22&&(fycongmapvc>=0.85&&fycongmapvc<=1.1))
   fyrd_util=2
endif
if(fycapcl=2,3,4,12,22&&fycongmapvc>1.1)
   fyrd_util=3
endif
if(fycapcl=1,6,16,26&&fycongmapvc<0.9)
   fyrd_util=1
endif
if(fycapcl=1,6,16,26&&(fycongmapvc>=0.9&&fycongmapvc<=1.05))
   fyrd_util=2
endif
if(fycapcl=1,6,16,26&&fycongmapvc>1.05)
   fyrd_util=3
endif
if(fycapcl=8,9,51,56&&fycongmapvc<0.5)
   fyrd_util=1
endif
if(fycapcl=8,9,51,56&&(fycongmapvc>=0.5&&fycongmapvc<=0.85))
   fyrd_util=2
endif
if(fycapcl=8,9,51,56&&fycongmapvc>0.85)
   fyrd_util=3
endif
;
;validation (crude)
;
valrat=0
if(c16dyd>0)
   valrat=bydyv/c16dyd
endif
;
;set up byfy phasing flags
;
;initalize flag
phasing=0
byconglev=1
fyconglev=1
;
;congestion levels
;1=low
;2=mod
;3=hi
;
if((bya3vc>=0.90&&bya3vc<1.05)||(byp3vc>=0.90&&byp3vc<1.05))
   byconglev=2
endif
if((bya3vc>=1.05)||(byp3vc>=1.05))
   byconglev=3
endif
;
if((fya3vc>=0.90&&fya3vc<1.05)||(fyp3vc>=0.90&&fyp3vc<1.05))
   fyconglev=2
endif
if((fya3vc>=1.05)||(fyp3vc>=1.05))
   fyconglev=3
endif
;
;phasing values
;1=no congestion in by or fy & no project
;2: by low, fy mod--no proj
;3: by low, fy hi--no proj
;4: by mod, fy low--no proj
;5: by mod, fy mod--no proj
;6: by mod, fy hi--no proj
;7: by hi, fy low--no proj
;8: by hi, fy mod--no proj
;9: by hi, fy hi--no proj
;
;11: by low, fy low--proj
;10: same as 11, but byfych>1.25
;12: by low, fy mod--proj
;13: by low, fy hi--proj
;14: by mod, fy low--proj
;15: by mod, fy mod--proj
;16: by mod, fy hi--proj
;17: by hi, fy low--proj
;18: by hi, fy mod--proj
;19: by hi, fy hi--proj
;
if(byconglev=1&&fyconglev=1)
   phasing=1
endif
if(byconglev=1&&fyconglev=2)
   phasing=2
endif
if(byconglev=1&&fyconglev=3)
   phasing=3
endif
if(byconglev=2&&fyconglev=1)
   phasing=4
endif
if(byconglev=2&&fyconglev=2)
   phasing=5
endif
if(byconglev=2&&fyconglev=3)
   phasing=6
endif
if(byconglev=3&&fyconglev=1)
   phasing=7
endif
if(byconglev=3&&fyconglev=2)
   phasing=8
endif
if(byconglev=3&&fyconglev=3)
   phasing=9
endif
if(proj_in=1&&newroad=0)
  phasing = phasing + 10
endif
if(proj_in=1&&newroad=1)
  phasing = phasing + 20
endif
if(phasing=11&&fybydyv_p>1.3&&(fya3vc>0.5||fyp3vc>0.5))
  phasing=10
endif
if(phasing>20&&(fya3vc>0.7||fyp3vc>0.7))
  phasing=20
endif
;worstcase congestion
;by_cong
merge record=false
endrun