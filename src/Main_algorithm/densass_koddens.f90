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
! Program unit: densass_koddens
! Description: To update the variables "deansass" and "koddens" of the 
!              structure array "pg"
!-------------------------------------------------------------------------------
subroutine densass_koddens
!------------------------
! Modules
!------------------------
use Dynamic_allocation_module
use Static_allocation_module
!------------------------
! Declarations
!------------------------
implicit none
integer(4) :: npi
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
!$omp parallel do default(none)                                                &
!$omp shared(nag,pg)                                                           &
!$omp private(npi)
         do npi=1,nag
            pg(npi)%koddens = 0
            pg(npi)%densass = pg(npi)%dens
         enddo
!$omp end parallel do
!------------------------
! Deallocations
!------------------------
return
end subroutine densass_koddens
