program main
  use version_updater, only: update_versions, show_help
  implicit none
  
  character(len=100) :: arg1, arg2
  integer :: num_args
  
  ! Get command-line arguments
  num_args = command_argument_count()
  
  if (num_args < 1) then
    call show_help()
    call exit(1)  ! Instead of stop 1
  end if
  
  ! Get first argument
  call get_command_argument(1, arg1)
  
  ! Check if help was requested
  if (arg1 == '-h' .or. arg1 == '--help') then
    call show_help()
    call exit(0)  ! Instead of stop 0
  end if
  
  ! If we got here, arg1 is the version
  if (num_args >= 2) then
    call get_command_argument(2, arg2)
    call update_versions(arg1, arg2)
  else
    call update_versions(arg1)
  end if
  
end program main

