!-------------------------------------------------------------------------------
! SPHERA v.9.0.0 (Smoothed Particle Hydrodynamics research software; mesh-less
! Computational Fluid Dynamics code).
! Copyright 2005-2020 (RSE SpA -formerly ERSE SpA, formerly CESI RICERCA,
! formerly CESI-Ricerca di Sistema)
!
! SPHERA authors and email contact are provided on SPHERA documentation.
!
! This file is part of SPHERA v.9.0.0
! SPHERA v.9.0.0 is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
! SPHERA is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
! You should have received a copy of the GNU General Public License
! along with SPHERA. If not, see <http://www.gnu.org/licenses/>.
!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
! Program unit: AddBoundaryContributions_to_ME3D                                
! Description: To compute boundary terms for 3D momentum equation (gradPsuro, 
!              ViscoF). Equations refer to particle npi. It performs implicit 
!              computation of gradPsuro (Di Monaco et al., 2011, EACFM).                        
!-------------------------------------------------------------------------------
#ifdef SPACE_3D
subroutine AddBoundaryContributions_to_ME3D(npi,Ncbf,tpres,tdiss,tvisc)
!------------------------
! Modules
!------------------------
use Static_allocation_module
use Hybrid_allocation_module
use Dynamic_allocation_module
use I_O_file_module
!------------------------
! Declarations
!------------------------
implicit none
integer(4),intent(in) :: npi,Ncbf
double precision,intent(inout),dimension(1:SPACEDIM) :: tpres,tdiss,tvisc
integer(4) :: sd,icbf,iface,ibdp,sdj,i,j,mati,stretch
double precision :: IntdWrm1dV,cinvisci,Monvisc,cinviscmult,pressi,dvn
double precision :: FlowRate1,Lb,L,minquotanode,maxquotanode
double precision :: Qii,roi,celeri,alfaMon,Mmult,IntGWZrm1dV
double precision,dimension(1:SPACEDIM) :: vb,vi,dvij,RHS,nnlocal,Grav_Loc 
double precision,dimension(1:SPACEDIM) :: ViscoMon,ViscoShear,LocPi,Gpsurob_Loc
double precision,dimension(1:SPACEDIM) :: Gpsurob_Glo
character(4) :: stretchtype
mati = pg(npi)%imed
cinvisci = pg(npi)%kin_visc
roi = pg(npi)%dens
pressi = pg(npi)%pres
Qii = (pressi + pressi) / roi
vi(:) = pg(npi)%var(:)
RHS(:) = zero
ViscoMon(:) = zero
ViscoShear(:) = zero
if ((Domain%time_stage==1).or.(Domain%time_split==1)) then 
   pg(npi)%kodvel = 0
   pg(npi)%velass(:) = zero
endif
!------------------------
! Explicit interfaces
!------------------------
!------------------------
! Allocations
!------------------------
!------------------------
! Initializations
!------------------------
!------------------------
! Statements
!------------------------
face_loop: do icbf = 1,Ncbf
   ibdp = BoundaryDataPointer(3,npi) + icbf - 1 
   iface = BoundaryDataTab(ibdp)%CloBoNum
   stretch = BoundaryFace(iface)%stretch
   stretchtype = Tratto(stretch)%tipo
   nnlocal(:) = BoundaryFace(iface)%T(:,3)
! Nothing to execute for open boundaries 
   if (stretchtype=="open") cycle face_loop
   if (stretchtype=="fixe".or.stretchtype=="tapi") then
! Local coordinates for particle Pi   
      LocPi(:) = BoundaryDataTab(ibdp)%LocXYZ(:) 
      if (LocPi(3)>zero) then                
! The face "iface" interacts with particle Pi
         dvn = zero
         do SD=1,SPACEDIM
            vb(SD) = BoundaryFace(iface)%velocity(SD)
            dvij(SD) = two * (vi(SD) - vb(SD))
            dvn = dvn + BoundaryFace(iface)%T(SD, 3) * dvij(SD)
! Gravity local components
            Grav_Loc(SD) = zero                           
            do sdj=1,SPACEDIM
               Grav_Loc(SD) = Grav_Loc(SD) + BoundaryFace(iface)%T(sdj, SD) *  &
                  Domain%grav(sdj)
            enddo
         enddo
! Boundary contribution to the pressre gradient term 
! Local components 
         do i=1,SPACEDIM
            Gpsurob_Loc(i) = -Qii * BoundaryDataTab(ibdp)%BoundaryIntegral(3+i)
            do j=1,SPACEDIM
               Gpsurob_Loc(i) = Gpsurob_Loc(i) -                               &
                  BoundaryDataTab(ibdp)%IntGiWrRdV(i,j) * Grav_Loc(j)
            enddo
         enddo
! Global components
         do i=1,SPACEDIM
            Gpsurob_Glo(i) = zero
            do j=1,SPACEDIM
               Gpsurob_Glo(i) = Gpsurob_Glo(i) + BoundaryFace(iface)%T(i,j) *  &
                                Gpsurob_Loc(j)
            enddo
            RHS(i) = RHS(i) + Gpsurob_Glo(i)
         enddo
! Boundary contributions to the viscosity terms 
         IntGWZrm1dV = BoundaryDataTab(ibdp)%BoundaryIntegral(7)
         IntdWrm1dV = BoundaryDataTab(ibdp)%BoundaryIntegral(3)
         alfaMon = Med(mati)%alfaMon
         if (alfaMon>zero.or.cinvisci>zero) then
! The volume viscosity term, depending on velocity divergence, can be 
! neglected (otherwise it may cause several problems); 
! further Monaghan's term is activated even for separating particles
            celeri = Med(mati)%celerita
            Monvisc = alfaMon * celeri * Domain%h 
            Mmult = -Monvisc * dvn * IntGWZrm1dV
            ViscoMon(:) = ViscoMon(:) + Mmult * nnlocal(:)
         endif
         if (cinvisci>zero) then
            if ((pg(npi)%laminar_flag==1).or.                                  &
                (Tratto(stretch)%laminar_no_slip_check.eqv..false.)) then
! The factor 2 is already present in "dvij"
               cinviscmult = cinvisci * IntdWrm1dV * Tratto(stretch)%ShearCoeff
               ViscoShear(:) = ViscoShear(:) + cinviscmult * dvij(:)
            endif
         endif
      endif
      elseif (stretchtype=="velo") then 
         if ((Domain%time_stage==1).or.(Domain%time_split==1)) then 
            pg(npi)%kodvel = 2
            pg(npi)%velass(:) = Tratto(stretch)%NormVelocity * nnlocal(:) 
         endif
         return
         elseif (stretchtype=="flow") then 
            if ((Domain%time_stage==1).or.(Domain%time_split==1)) then 
               pg(npi)%kodvel = 2
! Normal component of velocity 
               if (BoundaryFace(iface)%CloseParticles>0) then
                  minquotanode = 9999.d0
                  maxquotanode = const_m_9999
                  do i=1,BoundaryFace(iface)%nodes
                     if (minquotanode>                                         &
                        vertice(3,BoundaryFace(iface)%node(i)%name))           &
                        minquotanode =                                         &
                        vertice(3,BoundaryFace(iface)%node(i)%name)
                     if (maxquotanode<                                         &
                        vertice(3,BoundaryFace(iface)%node(i)%name))           &
                        maxquotanode =                                         &
                        vertice(3,BoundaryFace(iface)%node(i)%name)
                  enddo
                  Lb = BoundaryFace(iface)%CloseParticles_maxQuota -           &
                     minquotanode
                  L = maxquotanode - minquotanode
                  FlowRate1 = Tratto(stretch)%FlowRate * Lb / L
                  Tratto(stretch)%NormVelocity = doubleh * FlowRate1 /         &
                     (BoundaryFace(iface)%CloseParticles * Domain%PVolume)
                  else
                     Tratto(stretch)%NormVelocity = zero
               endif
               pg(npi)%velass(:) = Tratto(stretch)%NormVelocity * nnlocal(:) 
            endif
            return
! Inlet sections
            elseif (stretchtype=="sour") then         
               if ((Domain%time_stage==1).or.(Domain%time_split==1)) then 
                  pg(npi)%kodvel = 2
                  pg(npi)%velass(:) = Tratto(stretch)%NormVelocity * nnlocal(:) 
               endif
               return                                                          
   endif
enddo face_loop
! Adding boundary contributions to the momentum equation
  tpres(:) = tpres(:) - RHS(:)
  tdiss(:) = tdiss(:) - ViscoMon(:)
! For the sign of "ViscoShear", refer to the mathematical model
  tvisc(:) = tvisc(:) + ViscoShear(:)
!------------------------
! Deallocations
!------------------------
return
end subroutine AddBoundaryContributions_to_ME3D
#endif
