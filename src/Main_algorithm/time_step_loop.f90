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
! Program unit: time_step_loop         
! Description: loop over the simulation time steps                    
!-------------------------------------------------------------------------------
subroutine time_step_loop
!------------------------
! Modules
!------------------------
use I_O_file_module
use Static_allocation_module
use Hybrid_allocation_module
use Dynamic_allocation_module
use I_O_diagnostic_module
!------------------------
! Declarations
!------------------------
implicit none
logical :: done_flag,IC_removal_flag
integer(4) :: it,it_print,it_memo,it_rest,num_out
double precision :: dt_previous_step,dtvel
integer(4),external :: CellNumber
!------------------------
! Explicit interfaces
!------------------------
!------------------------
! Allocations
!------------------------
!------------------------
! Initializations
!------------------------
on_going_time_step = -999
EpOrdGrid = 0
num_out = 0
#ifdef SPACE_3D
   SourceFace = 0
#elif defined SPACE_2D
      SourceSide = 0
#endif
it_eff = it_start
it_print = it_start
it_memo = it_start
it_rest = it_start
! Initializing the time stage for time integration
if (Domain%time_split==0) Domain%time_stage = 1
IC_removal_flag = .false.
!------------------------
! Statements
!------------------------
call liquid_particle_ID_array
! Introductory procedure for inlet conditions
#ifdef SPACE_3D
   call PreSourceParticles_3D
#elif defined SPACE_2D
      call PreSourceParticles_2D
#endif
! SPH parameters 
call start_and_stop(2,10)
if (Domain%tipo=="bsph") on_going_time_step = -2
call CalcVarLength
if ((on_going_time_step==-2).and.(Domain%tipo=="bsph")) on_going_time_step =   &
   it_start
call start_and_stop(3,10)
if ((on_going_time_step==it_start).and.(Domain%tipo=="bsph")) then
   call start_and_stop(2,9)
   call removing_DBSPH_fictitious_reservoirs
   IC_removal_flag = .true.
   call start_and_stop(3,9)
endif
if (n_bodies>0) then
   call start_and_stop(2,19)
   call initial_fluid_removal_in_solid_bodies
   IC_removal_flag = .true.
   call start_and_stop(3,19)
endif
if (IC_removal_flag.eqv..true.) then
   call start_and_stop(2,9)
   call OrdGrid1
   call liquid_particle_ID_array
   call start_and_stop(3,9)
   call start_and_stop(2,10)
! This fictitious value avoid CalcVarlength computing Gamma, sigma and density 
! for this very call     
   on_going_time_step = - 1
   call CalcVarLength
! The correct value of "on_going_time_step" is restored
   on_going_time_step = it_start
   call start_and_stop(3,10)
endif
! Subroutine for wall BC treatment (DB-SPH)
! Density and pressure updates for wall elements: MUSCL + LPRS + 
! equation of state 
call start_and_stop(2,18)
if ((Domain%tipo=="bsph").and.(nag>0).and.(DBSPH%n_w>0)) then
   call Gradients_to_MUSCL   
   call BC_wall_elements
endif
call start_and_stop(3,18)
! Pressure initialization for body particles
if (n_bodies>0) then
   call start_and_stop(2,19)
   call body_pressure_mirror
   call body_pressure_postpro
   call start_and_stop(3,19)
endif
! To evaluate the close boundaries and integrals for the current particle in 
! every loop and storing them in the general storage array. Computation and 
! storage of the intersections between the kernel support and the frontier and 
! the corresponding boundary integrals (SA-SPH).
if (Domain%tipo=="semi") then
   call start_and_stop(2,11)
#ifdef SPACE_3D
      call ComputeBoundaryDataTab_3D
#elif defined SPACE_2D
         call ComputeBoundaryDataTab_2D
#endif
   call start_and_stop(3,11)
endif
! To evaluate the properties that must be attributed to the fixed particles
if (Domain%NormFix) call NormFix
if (uerr>0) write(uerr,"(a,1x,a)") " Running case:",trim(nomecas2)
! To initialize the output files
if (ulog>0) then
   it_print = it_eff
   call Print_Results(it_eff,it_print,'inizio')
endif
if (nres>0) then
   it_memo = it_eff
   it_rest = it_eff
   call Memo_Results(it_eff,it_memo,it_rest,dtvel,'inizio')
endif
if (vtkconv) then
   call result_converter('inizio')
endif
! To assess the initial time step
if (it_start==0) call time_step_duration
it = it_start
call time_elapsed_IC
TIME_STEP_DO: do while (it<=Domain%itmax)
   done_flag = .false.
! Set the time step ID
   it = it + 1
   on_going_time_step = it
   it_eff = it
! To store the old time step duration, to evaluate the new value of time step 
! duration and update the simulation time
   dt_previous_step = dt
! Stability criteria
   if (nag>0) call time_step_duration
   simulation_time = simulation_time + dt
   if (uerr>0) write(uerr,"(a,i8,a,g13.6,a,g12.4,a,i8,a,i5)") " it= ",it,      &
      "   time= ",simulation_time,"  dt= ",dt,"    npart= ",nag,"   out= ",    &
      num_out
   TIME_STAGE_DO: do while ((done_flag.eqv.(.false.)).or.((Domain%RKscheme>1)  &
      .and.(Domain%time_stage>1)))
      if (Domain%time_split==0) then
! Explicit RK schemes
! SPH parameters 
         call start_and_stop(2,10)
         if ((Domain%tipo=="semi").and.(Domain%time_stage<2)) call CalcVarLength
         call start_and_stop(3,10)
! To evaluate the close boundaries and integrals
! for the current particle in every loop and storing them in the general 
! storage array.
! Computation and storage of the boundary integrals
         if (Domain%tipo=="semi") then
            call start_and_stop(2,11)
#ifdef SPACE_3D
               call ComputeBoundaryDataTab_3D
#elif defined SPACE_2D
                  call ComputeBoundaryDataTab_2D
#endif
            call start_and_stop(3,11)
            endif
      endif
      if (Domain%tipo=="semi") call fluid_particle_imposed_kinematics
      if ((Domain%time_split==0).and.(Domain%time_stage==1)) then
! Erosion criterium + continuity equation RHS
         call start_and_stop(2,12)
         if (Granular_flows_options%KTGF_config>0) call KTGF_update
         call liquid_particle_ID_array
      endif
! Momentum equation 
      call start_and_stop(2,6)
      call RHS_momentum_equation
! Balance equations RHS for body dynamics
      if (n_bodies>0) then
         call start_and_stop(3,6)
         call start_and_stop(2,19)
         call RHS_body_dynamics(dtvel)
         call start_and_stop(3,19)
         call start_and_stop(2,6)
      endif
! Time integration scheme for momentum equations 
      if (Domain%time_split==0) then   
! Explicit RK schemes
         call start_and_stop(3,6)
! Velocity smoothing, trajectory equation, BC, neighboring parameters (start)
         elseif (Domain%time_split==1) then
            call Leapfrog_momentum(dt_previous_step,dtvel)
            call start_and_stop(3,6)
! Time integration for body dynamics
            if (n_bodies>0) then
               call start_and_stop(2,19)
               call time_integration_body_dynamics(dtvel)
               call start_and_stop(3,19)
            endif
! Partial smoothing for velocity: start 
            call start_and_stop(2,7)
            if (Domain%TetaV>1.d-9) call velocity_smoothing
            call velocity_smoothing_2
            call start_and_stop(3,7)
! Partial smoothing for velocity: end
! Update the particle positions
            call start_and_stop(2,8)
            call Leapfrog_trajectories
            call start_and_stop(3,8)
! Check on the particles gone out of the domain throughout the opened 
! faces/sides
            call start_and_stop(2,9)
#ifdef SPACE_3D
            if (NumOpenFaces>0) call CancelOutgoneParticles_3D
#elif defined SPACE_2D
               if (NumOpenSides>0) call CancelOutgoneParticles_2D
#endif
! Adding new particles from the inlet section
#ifdef SPACE_3D
            if (SourceFace/=0) then
#elif defined SPACE_2D
            if (SourceSide/=0) then
#endif
               call GenerateSourceParticles
            endif
! Particle reordering
            call OrdGrid1
            call start_and_stop(3,9)
! Set the parameters for the fixed particles 
            if (Domain%NormFix) call NormFix
! SPH parameters
            call start_and_stop(2,10)
            call CalcVarLength
            call start_and_stop(3,10)
! Assessing the close boundaries and the integrals
! for the current particle in every loop and storing them in the general 
! storage array.
! Computation and storage of the boundary integrals
            if (Domain%tipo=="semi") then
               call start_and_stop(2,11)
#ifdef SPACE_3D
                  call ComputeBoundaryDataTab_3D
#elif defined SPACE_2D
                     call ComputeBoundaryDataTab_2D
#endif
               call start_and_stop(3,11)
            endif
      endif
! Continuity equation 
! Erosion criterion + continuity equation RHS 
      call start_and_stop(2,12)
      if (Granular_flows_options%KTGF_config>0) then  
         if (Domain%time_split==1) then
            call KTGF_update
            call liquid_particle_ID_array
         endif
! To compute the second invariant of the strain-rate tensor and density 
! derivatives
         call Continuity_Equation
         else 
! No erosion criterion  
! To compute the second invariant of the strain-rate tensor and density 
! derivatives
            call Continuity_Equation
            if (Domain%time_split==1) call liquid_particle_ID_array
      endif
      if ((Domain%time_stage==1).or.(Domain%time_split==1)) then
         pg(:)%koddens = 0
      endif
      if (Domain%tipo=="semi") call SASPH_continuity
      if (Domain%time_split==0) then   
! Explicit RK schemes
         call start_and_stop(3,12)
         elseif (Domain%time_split==1) then
            call Leapfrog_continuity
            call start_and_stop(3,12)
! Equation of state 
            call start_and_stop(2,13)
            call CalcPre
            call start_and_stop(3,13)
! Continuity equation: end
            if (n_bodies>0) then
               call start_and_stop(2,19)
               call body_pressure_mirror
               call start_and_stop(3,19)
            endif
      endif
      if (Domain%time_split==0) call time_integration
! Explicit RK schemes
! Partial smoothing for pressure and density update
      if (Domain%TetaP>zero) then
         call start_and_stop(2,14)
         if (Domain%Psurf=='s') then
            call inter_SmoothPres
            elseif (Domain%Psurf=='a') then
#ifdef SPACE_3D
                  call PressureSmoothing_3D         
#elif defined SPACE_2D
                     call PressureSmoothing_2D
#endif
         endif
         call start_and_stop(3,14)
      endif
      if (n_bodies>0) then
         call start_and_stop(2,19)
         call body_pressure_postpro
         call start_and_stop(3,19)
      endif
      call start_and_stop(2,20)
      if (Granular_flows_options%KTGF_config==1) call mixture_viscosity 
      call start_and_stop(3,20)
      if (Domain%tipo=="semi") then
! Boundary Conditions: start
! BC: checks for the particles gone out of the domain throughout the opened 
! faces/sides
         if ((Domain%time_split==0).and.(Domain%time_stage==Domain%RKscheme))  &
            then
            call start_and_stop(2,9)
#ifdef SPACE_3D
            if (NumOpenFaces>0) call CancelOutgoneParticles_3D
#elif defined SPACE_2D
               if (NumOpenSides>0) call CancelOutgoneParticles_2D
#endif
! Adding new particles at the inlet section
#ifdef SPACE_3D
            if (SourceFace/=0) then
#elif defined SPACE_2D
            if (SourceSide/=0) then
#endif
               call GenerateSourceParticles
            endif
! Particle reordering on the background positioning grid
            call OrdGrid1
            call start_and_stop(3,9)
! Set the parameters for the fixed particles 
            if (Domain%NormFix) call NormFix
            call liquid_particle_ID_array
         endif
! Boundary Conditions: end
      endif
! Subroutine for wall BC treatment (DB-SPH)
! Density and pressure updates for wall elements: MUSCL + LPRS  
! + state equation 
      call start_and_stop(2,18)
      if ((Domain%tipo=="bsph").and.(nag>0).and.(DBSPH%n_w>0)) then
         call Gradients_to_MUSCL   
         call BC_wall_elements
      endif
      call start_and_stop(3,18)
! Update of the time stage
      if ((Domain%RKscheme>1).and.(Domain%time_split==0)) then
         Domain%time_stage = modulo(Domain%time_stage,Domain%RKscheme)
         Domain%time_stage = Domain%time_stage + 1
            else
               done_flag = .true.
      endif
   enddo TIME_STAGE_DO
   if (Domain%time_split==0) dtvel = dt
   call time_step_post_processing(it_print,it_memo,it_rest,it,dtvel)
! If the "kill file" exists, then the run is stopped and last results are saved.
   inquire(file=nomefilekill,EXIST=kill_flag)
   if (kill_flag) exit TIME_STEP_DO
   if (simulation_time>=Domain%tmax) exit TIME_STEP_DO
enddo TIME_STEP_DO
! Post-processing: log on the last time step
if (it_eff/=it_print.and.ulog>0) then
   it_print = it_eff
   call Print_Results(it_eff,it_print,'fine__')
endif
! Post-processing: last update of the restart file
if (it_eff/=it_memo.and.nres>0) then
   call Memo_Results(it_eff,it_memo,it_rest,dtvel,'fine__')
endif
! Post-processing: last writing of the output files for Paraview
if (vtkconv) then
   call result_converter ('fine__')
endif
! Post-processing: end of the log file
call final_log
!------------------------
! Deallocations
!------------------------
if ((Domain%tipo=="bsph").and.(DBSPH%n_w>0)) deallocate(pg_w)
return
end subroutine time_step_loop
