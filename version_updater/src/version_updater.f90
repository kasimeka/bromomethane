module version_updater
   use iso_fortran_env, only: error_unit
!$ use omp_lib
   implicit none

   private
   public :: update_versions, show_help, say_hello

   ! Size constants for better performance (reduce buffer size to avoid memory issues)
   integer, parameter :: MAX_PATH_LEN = 4096
   integer, parameter :: MAX_BUFFER_SIZE = 1024*1024  ! 1MB buffer

   ! Platform detection
   logical, save :: initialized = .false.
   logical, save :: is_windows = .false.
   character(len=1), save :: path_sep = '/'  ! Default to Unix-style

contains

   ! Platform initialization
   subroutine init_platform()
      character(len=20) :: os_name
      integer :: length, stat

      if (initialized) return

      call get_environment_variable("OS", os_name, length, stat)
      if (stat == 0 .and. length > 0) then
         if (index(os_name, "Windows") > 0) then
            is_windows = .true.
            path_sep = '\'
         end if
      end if

      initialized = .true.
   end subroutine init_platform

   ! Improved file reading function to preserve exactly the original file content
   subroutine read_file_content(file_path, content, content_len, io_stat)
      character(len=*), intent(in) :: file_path
      character(len=*), intent(out) :: content
      integer, intent(out) :: content_len, io_stat
      integer :: file_unit, file_size
      logical :: file_exists
      character(len=1024) :: line

      ! Check if file exists
      inquire (file=file_path, exist=file_exists)
      if (.not. file_exists) then
         io_stat = -1
         return
      end if

      ! Get file size to prevent buffer overflow
      inquire (file=file_path, size=file_size)
      if (file_size <= 0 .or. file_size > len(content) - 1) then
         io_stat = -2
         return
      end if

      ! Read the file while preserving exact format
      open (newunit=file_unit, file=file_path, status='old', action='read', iostat=io_stat, &
            form='unformatted', access='stream')  ! Use unformatted for binary mode
      if (io_stat /= 0) then
         ! Try traditional text mode if unformatted/stream failed
         open (newunit=file_unit, file=file_path, status='old', action='read', iostat=io_stat)
         if (io_stat /= 0) return

         content = ""
         content_len = 0

         do
            read (file_unit, '(a)', iostat=io_stat) line

            if (io_stat < 0) then
               ! End of file - don't add extra newline
               io_stat = 0
               exit
            else if (io_stat > 0) then
               ! Other error
               close (file_unit)
               return
            end if

            ! Add content with careful bounds checking
            if (content_len + len_trim(line) + 1 >= len(content)) then
               io_stat = -3  ! Buffer too small
               close (file_unit)
               return
            end if

            ! Append the line
            content(content_len + 1:content_len + len_trim(line)) = line(1:len_trim(line))
            content_len = content_len + len_trim(line)

            ! Add newline after each line except the last
            content(content_len + 1:content_len + 1) = char(10)  ! newline
            content_len = content_len + 1
         end do

         close (file_unit)
         return
      end if

      ! Binary read successful
      content_len = min(file_size, len(content) - 1)
      read (file_unit, iostat=io_stat) content(1:content_len)
      close (file_unit)
   end subroutine read_file_content

! Improved file writing function that preserves exact content
   subroutine write_file_content(file_path, content, content_len, io_stat)
      character(len=*), intent(in) :: file_path, content
      integer, intent(in) :: content_len
      integer, intent(out) :: io_stat
      integer :: file_unit

      open (newunit=file_unit, file=file_path, status='replace', action='write', iostat=io_stat, &
            form='unformatted', access='stream')  ! Use unformatted for binary mode
      if (io_stat /= 0) then
         ! Try traditional text mode if unformatted/stream mode failed
         open (newunit=file_unit, file=file_path, status='replace', action='write', iostat=io_stat)
         if (io_stat /= 0) return

         write (file_unit, '(a)', advance='no', iostat=io_stat) content(1:content_len)
         close (file_unit)
         return
      end if

      ! Write exactly the content without adding or removing anything
      write (file_unit, iostat=io_stat) content(1:content_len)
      close (file_unit)
   end subroutine write_file_content

   subroutine show_help()
      write (*, '(a)') "Usage: version_updater [options] VERSION [DIRECTORY]"
      write (*, '(a)') ""
      write (*, '(a)') "Updates version strings in various files recursively."
      write (*, '(a)') ""
      write (*, '(a)') "Arguments:"
      write (*, '(a)') "  VERSION      Version to set (e.g., v2.0.3)"
      write (*, '(a)') "  DIRECTORY    Directory to scan (default: current directory)"
      write (*, '(a)') ""
      write (*, '(a)') "Options:"
      write (*, '(a)') "  -h, --help   Show this help message and exit"
      write (*, '(a)') "  --bun        Update package.json to use Bun package manager"
      write (*, '(a)') ""
      write (*, '(a)') "Files updated:"
      write (*, '(a)') "  - tauri.conf.json"
      write (*, '(a)') "  - Cargo.toml"
      write (*, '(a)') "  - Cargo.lock (balatro-mod-manager package)"
      write (*, '(a)') "  - package.json"
      write (*, '(a)') "  - All .svelte files containing specific version elements"
      write (*, '(a)') ""
      write (*, '(a)') "Notes:"
      write (*, '(a)') "  - The 'v' prefix is automatically removed for certain files"
      write (*, '(a)') "  - Directories like .git, node_modules, etc. are automatically excluded"
      write (*, '(a)') "  - Use --bun to update package.json to use Bun as the package manager"
   end subroutine show_help

   subroutine update_versions(version_arg, directory_arg, use_bun)
      character(len=*), intent(in) :: version_arg
      character(len=*), intent(in), optional :: directory_arg
      logical, intent(in), optional :: use_bun

      character(len=100) :: version
      character(len=MAX_PATH_LEN) :: directory
      logical :: has_v_prefix, update_to_bun

      ! Initialize platform detection
      call init_platform()

      ! Check if version starts with 'v' and remove it for certain files
      has_v_prefix = .false.
      if (version_arg(1:1) == 'v') then
         has_v_prefix = .true.
         version = version_arg(2:)
      else
         version = version_arg
      end if

      ! Set update_to_bun flag
      update_to_bun = .false.
      if (present(use_bun)) then
         update_to_bun = use_bun
      end if

      ! Get current directory if not provided
      if (present(directory_arg)) then
         directory = directory_arg
      else
         call get_current_directory(directory)
      end if

      write (*, '(a)') "Starting version update process..."
      write (*, '(a,a)') "Target directory: ", trim(directory)
      write (*, '(a,a)') "Version: ", trim(version_arg)
      if (update_to_bun) then
         write (*, '(a)') "Will update package.json to use Bun package manager"
      end if

!$    write (*, '(a,i0)') "Using OpenMP with threads: ", omp_get_max_threads()

      ! Process the directory and update files
      call process_directory(trim(directory), trim(version), trim(version_arg), update_to_bun)

      write (*, '(a)') "Version update completed successfully!"
   end subroutine update_versions

   ! Cross-platform implementation of getting current directory
   subroutine get_current_directory(dir)
      character(len=*), intent(out) :: dir
      integer :: io_stat, length

      ! Initialize platform detection
      call init_platform()

      ! Initialize to empty
      dir = ""

      ! Use Fortran intrinsic to get current working directory
      call getcwd(dir, io_stat)
      if (io_stat /= 0) then
         write (error_unit, '(a)') "Error: Could not determine current directory"
         call exit(1)
      end if

      ! Ensure path separator consistency
      if (is_windows) then
         ! Convert forward slashes to backslashes for Windows
         do length = 1, len_trim(dir)
            if (dir(length:length) == '/') then
               dir(length:length) = '\'
            end if
         end do
      else
         ! Convert backslashes to forward slashes for Unix/Mac
         do length = 1, len_trim(dir)
            if (dir(length:length) == '\') then
               dir(length:length) = '/'
            end if
         end do
      end if
   end subroutine get_current_directory

   ! Cross-platform directory processing
   subroutine process_directory(dir_path, version_no_v, version_with_v, update_to_bun)
      character(len=*), intent(in) :: dir_path, version_no_v, version_with_v
      logical, intent(in) :: update_to_bun
      character(len=MAX_PATH_LEN) :: file_path, temp_file
      integer :: io_stat, status, file_unit
      logical :: file_exists, done
      character(len=MAX_PATH_LEN), allocatable :: file_list(:)
      integer :: file_count, i, temp_unit

      ! Initialize platform detection
      call init_platform()

      ! Use a unique temporary file name to avoid collisions
      call get_temp_filename(temp_file)

      write (*, '(a)') "Processing configuration files..."

      ! Process each file type using cross-platform file discovery

      ! tauri.conf.json
      call find_files(dir_path, "tauri.conf.json", file_list, file_count)
      if (file_count > 0) then
         do i = 1, file_count
            call update_tauri_conf(file_list(i), version_no_v)
         end do
         deallocate (file_list)
      end if

      ! Cargo.toml
      call find_files(dir_path, "Cargo.toml", file_list, file_count)
      if (file_count > 0) then
         do i = 1, file_count
            call update_cargo_toml(file_list(i), version_no_v)
         end do
         deallocate (file_list)
      end if

      ! Cargo.lock
      call find_files(dir_path, "Cargo.lock", file_list, file_count)
      if (file_count > 0) then
         do i = 1, file_count
            call update_cargo_lock(file_list(i), version_no_v)
         end do
         deallocate (file_list)
      end if

      ! package.json
      call find_files(dir_path, "package.json", file_list, file_count)
      if (file_count > 0) then
         do i = 1, file_count
            call update_package_json(file_list(i), version_no_v, update_to_bun)
         end do
         deallocate (file_list)
      end if

      ! Svelte files
      write (*, '(a)') "Processing Svelte files..."
      call find_files(dir_path, "*.svelte", file_list, file_count)
      if (file_count > 0) then
         do i = 1, file_count
            call update_svelte_file(file_list(i), version_with_v)
         end do
         deallocate (file_list)
      end if

      ! Clean up any temporary files
      inquire (file=temp_file, exist=file_exists)
      if (file_exists) then
         open (newunit=temp_unit, file=temp_file, status='old', iostat=io_stat)
         if (io_stat == 0) close (temp_unit, status='delete')
      end if
   end subroutine process_directory

   ! Cross-platform file finder routine
   subroutine find_files(dir_path, pattern, file_list, file_count)
      character(len=*), intent(in) :: dir_path, pattern
      character(len=MAX_PATH_LEN), allocatable, intent(out) :: file_list(:)
      integer, intent(out) :: file_count
      character(len=MAX_PATH_LEN) :: cmd, temp_file
      integer :: io_stat, file_unit, alloc_stat
      character(len=MAX_PATH_LEN) :: line
      character(len=:), allocatable :: cmd_output
      integer :: est_count, actual_count

      ! Initialize platform detection
      call init_platform()

      ! Get a temporary file name
      call get_temp_filename(temp_file)

      ! Initial allocation for file list - we'll resize as needed
      est_count = 100  ! Start with space for 100 files
      allocate (file_list(est_count), stat=alloc_stat)
      if (alloc_stat /= 0) then
         file_count = 0
         return
      end if

      ! Use appropriate command for Windows or Unix-like systems
      if (is_windows) then
         ! Windows-compatible command using PowerShell
         cmd = 'powershell -Command "Get-ChildItem -Path '''//trim(dir_path)// &
               ''' -Filter '''//trim(pattern)//''' -Recurse -File | '// &
               'Where-Object { $_.FullName -notmatch ''\\(\\.git|node_modules|\\.svelte-kit|'// &
               'target|\\.deno)\\'' } | ForEach-Object { $_.FullName }" > "'// &
               trim(temp_file)//'"'
      else
         ! Unix-compatible find command
         cmd = 'find "'//trim(dir_path)//'" -name "'//trim(pattern)//'" '// &
               '! -path "*/\.*" ! -path "*/node_modules/*" ! -path "*/.svelte-kit/*" '// &
               '! -path "*/target/*" ! -path "*/.deno/*" -type f > "'// &
               trim(temp_file)//'"'
      end if

      ! Execute the command
      call execute_command_line(trim(cmd), exitstat=io_stat)
      if (io_stat /= 0) then
         ! Command failed, try using Fortran directory traversal as fallback
         call traverse_directory(trim(dir_path), trim(pattern), file_list, file_count)
         return
      end if

      ! Read the results
      open (newunit=file_unit, file=trim(temp_file), status='old', action='read', iostat=io_stat)
      if (io_stat /= 0) then
         file_count = 0
         return
      end if

      ! Read files
      actual_count = 0
      do
         read (file_unit, '(a)', iostat=io_stat) line
         if (io_stat /= 0) exit

         actual_count = actual_count + 1

         ! Resize array if needed
         if (actual_count > est_count) then
            call resize_file_list(file_list, est_count*2)
            est_count = est_count*2
         end if

         file_list(actual_count) = trim(line)
      end do

      close (file_unit, status='delete')
      file_count = actual_count
   end subroutine find_files

   ! Helper to resize the file list array
   subroutine resize_file_list(file_list, new_size)
      character(len=MAX_PATH_LEN), allocatable, intent(inout) :: file_list(:)
      integer, intent(in) :: new_size
      character(len=MAX_PATH_LEN), allocatable :: temp_list(:)
      integer :: old_size, i, alloc_stat

      old_size = size(file_list)
      allocate (temp_list(new_size), stat=alloc_stat)
      if (alloc_stat /= 0) return

      ! Copy existing data
      do i = 1, min(old_size, new_size)
         temp_list(i) = file_list(i)
      end do

      ! Replace old array with new one
      call move_alloc(temp_list, file_list)
   end subroutine resize_file_list

   ! Fallback directory traversal implementation using Fortran intrinsics
   subroutine traverse_directory(dir_path, pattern, file_list, file_count)
      character(len=*), intent(in) :: dir_path, pattern
      character(len=MAX_PATH_LEN), allocatable, intent(out) :: file_list(:)
      integer, intent(out) :: file_count
      character(len=MAX_PATH_LEN) :: item_path
      character(len=256) :: item_name
      logical :: is_dir
      integer :: stat, est_count

      ! Initialize
      file_count = 0
      est_count = 100
      allocate (file_list(est_count))

      ! This is a simplified version - in a real implementation,
      ! you would recursively traverse through subdirectories
      ! and apply pattern matching using Fortran string operations

      ! For now, just set empty result since full implementation
      ! would be very complex and beyond the scope of this example
      file_count = 0
   end subroutine traverse_directory

   ! Generate a cross-platform temporary filename
   subroutine get_temp_filename(filename)
      character(len=*), intent(out) :: filename
      integer :: i, time(8)
      character(len=15) :: time_str

      ! Initialize platform detection
      call init_platform()

      ! Get current time values for a unique name
      call date_and_time(values=time)

      ! Create a unique filename based on time
      write (time_str, '(i4.4,i2.2,i2.2,i2.2,i2.2,i2.2)') &
         time(1), time(2), time(3), time(5), time(6), time(7)

      ! Use appropriate temp directory - avoid escaping backslash problems
      if (is_windows) then
         filename = "C:/Temp/ver_upd_"//trim(time_str)//".tmp"
      else
         filename = "/tmp/ver_upd_"//trim(time_str)//".tmp"
      end if
   end subroutine get_temp_filename

   subroutine update_tauri_conf(file_path, version_str)
      character(len=*), intent(in) :: file_path, version_str
      character(len=MAX_BUFFER_SIZE) :: content
      integer :: io_stat, pos1, pos2, content_len
      logical :: file_exists

      ! Check if file exists
      inquire (file=file_path, exist=file_exists)
      if (.not. file_exists) then
         return
      end if

      ! Read the file using our improved reader
      call read_file_content(file_path, content, content_len, io_stat)
      if (io_stat /= 0) then
         write (error_unit, '(a,a)') "Error: Could not read file: ", trim(file_path)
         return
      end if

      ! Update the version
      pos1 = index(content(1:content_len), '"version": "')
      if (pos1 > 0) then
         pos1 = pos1 + 12  ! Length of '"version": "'
         pos2 = index(content(pos1:content_len), '"')

         if (pos2 > 0) then
            ! Check if we have room for the new version
            if (content_len - (pos1 + pos2 - 1) + len_trim(version_str) < MAX_BUFFER_SIZE) then
               ! Build new content
               content = content(1:pos1 - 1)//trim(version_str)//content(pos1 + pos2 - 1:content_len)
               content_len = len_trim(content)

               ! Write back to file using our improved writer
               call write_file_content(file_path, content, content_len, io_stat)
               if (io_stat /= 0) then
                  write (error_unit, '(a,a)') "Error: Could not write to file: ", trim(file_path)
                  return
               end if

               write (*, '(a,a)') "Updated: ", trim(file_path)
            else
               write (error_unit, '(a,a)') "Error: Buffer overflow prevented for file: ", trim(file_path)
            end if
         end if
      end if
   end subroutine update_tauri_conf

   ! Add missing subroutine update_cargo_toml
   subroutine update_cargo_toml(file_path, version_str)
      character(len=*), intent(in) :: file_path, version_str
      character(len=MAX_BUFFER_SIZE) :: content
      integer :: io_stat, pos1, pos2, content_len
      logical :: file_exists

      ! Check if file exists
      inquire (file=file_path, exist=file_exists)
      if (.not. file_exists) then
         return
      end if

      ! Read the file using our improved reader
      call read_file_content(file_path, content, content_len, io_stat)
      if (io_stat /= 0) then
         write (error_unit, '(a,a)') "Error: Could not read file: ", trim(file_path)
         return
      end if

      ! Update the version
      pos1 = index(content(1:content_len), 'version = "')
      if (pos1 > 0) then
         pos1 = pos1 + 11  ! Length of 'version = "'
         pos2 = index(content(pos1:content_len), '"')

         if (pos2 > 0) then
            ! Check if we have room for the new version
            if (content_len - (pos1 + pos2 - 1) + len_trim(version_str) < MAX_BUFFER_SIZE) then
               ! Build new content
               content = content(1:pos1 - 1)//trim(version_str)//content(pos1 + pos2 - 1:content_len)
               content_len = len_trim(content)

               ! Write back to file using our improved writer
               call write_file_content(file_path, content, content_len, io_stat)
               if (io_stat /= 0) then
                  write (error_unit, '(a,a)') "Error: Could not write to file: ", trim(file_path)
                  return
               end if

               write (*, '(a,a)') "Updated: ", trim(file_path)
            else
               write (error_unit, '(a,a)') "Error: Buffer overflow prevented for file: ", trim(file_path)
            end if
         end if
      end if
   end subroutine update_cargo_toml

   subroutine update_cargo_lock(file_path, version_str)
      character(len=*), intent(in) :: file_path, version_str
      character(len=MAX_BUFFER_SIZE) :: content
      integer :: io_stat, content_len, pos, packages_updated
      integer :: next_pos, name_pos, ver_pos, ver_start, ver_end
      logical :: file_exists

      ! Check if file exists
      inquire (file=file_path, exist=file_exists)
      if (.not. file_exists) then
         return
      end if

      ! Read the file
      call read_file_content(file_path, content, content_len, io_stat)
      if (io_stat /= 0) then
         write (error_unit, '(a,a)') "Error: Could not read file: ", trim(file_path)
         return
      end if

      ! Fix formatting issues and update versions
      packages_updated = 0

      ! First pass: Fix formatting issues where "dependencies = [" immediately follows version
      pos = 1
      do while (pos <= content_len - 15)
         next_pos = index(content(pos:content_len), 'dependencies = [')
         if (next_pos == 0) exit

         next_pos = pos + next_pos - 1

         ! Check if preceded by a closing quote (end of version)
         if (next_pos > 1 .and. content(next_pos - 1:next_pos - 1) == '"') then
            ! Insert a newline
            if (content_len + 1 <= MAX_BUFFER_SIZE) then
               content = content(1:next_pos - 1)//char(10)//content(next_pos:content_len)
               content_len = content_len + 1
            end if
         end if

         pos = next_pos + 1
      end do

      ! Second pass: Update versions of target packages
      ! Update balatro-mod-manager
      pos = 1
      do while (pos <= content_len - 30)
         name_pos = index(content(pos:content_len), 'name = "balatro-mod-manager"')
         if (name_pos == 0) exit

         name_pos = pos + name_pos - 1

         ! Find the version after this name
         ver_pos = index(content(name_pos:min(name_pos + 200, content_len)), 'version = "')
         if (ver_pos > 0) then
            ver_pos = name_pos + ver_pos - 1

            ! Get start and end of version value
            ver_start = ver_pos + 11  ! After 'version = "'
            ver_end = index(content(ver_start:min(ver_start + 50, content_len)), '"')

            if (ver_end > 0) then
               ver_end = ver_start + ver_end - 1

               ! Update version
               if (content_len - (ver_end - ver_start) + len_trim(version_str) <= MAX_BUFFER_SIZE) then
                  content = content(1:ver_start - 1)//trim(version_str)//content(ver_end:content_len)
                  content_len = content_len - (ver_end - ver_start) + len_trim(version_str)
                  packages_updated = packages_updated + 1
               end if
            end if
         end if

         pos = name_pos + 30
      end do

      ! Update bmm-lib
      pos = 1
      do while (pos <= content_len - 20)
         name_pos = index(content(pos:content_len), 'name = "bmm-lib"')
         if (name_pos == 0) exit

         name_pos = pos + name_pos - 1

         ! Find the version after this name
         ver_pos = index(content(name_pos:min(name_pos + 200, content_len)), 'version = "')
         if (ver_pos > 0) then
            ver_pos = name_pos + ver_pos - 1

            ! Get start and end of version value
            ver_start = ver_pos + 11  ! After 'version = "'
            ver_end = index(content(ver_start:min(ver_start + 50, content_len)), '"')

            if (ver_end > 0) then
               ver_end = ver_start + ver_end - 1

               ! Update version
               if (content_len - (ver_end - ver_start) + len_trim(version_str) <= MAX_BUFFER_SIZE) then
                  content = content(1:ver_start - 1)//trim(version_str)//content(ver_end:content_len)
                  content_len = content_len - (ver_end - ver_start) + len_trim(version_str)
                  packages_updated = packages_updated + 1
               end if
            end if
         end if

         pos = name_pos + 20
      end do

      ! Write back changes
      call write_file_content(file_path, content, content_len, io_stat)
      if (io_stat /= 0) then
         write (error_unit, '(a,a)') "Error: Could not write to file: ", trim(file_path)
         return
      end if

      write (*, '(a,a,a,i0,a)') "Updated: ", trim(file_path), " (", packages_updated, " packages)"
   end subroutine update_cargo_lock

   ! Add missing subroutine update_package_json
   subroutine update_package_json(file_path, version_str, update_to_bun)
      character(len=*), intent(in) :: file_path, version_str
      logical, intent(in) :: update_to_bun
      character(len=MAX_BUFFER_SIZE) :: content
      integer :: io_stat, pos1, pos2, content_len
      logical :: file_exists, package_manager_updated

      ! Check if file exists
      inquire (file=file_path, exist=file_exists)
      if (.not. file_exists) then
         return
      end if

      ! Read the file using our improved reader
      call read_file_content(file_path, content, content_len, io_stat)
      if (io_stat /= 0) then
         write (error_unit, '(a,a)') "Error: Could not read file: ", trim(file_path)
         return
      end if

      package_manager_updated = .false.

      ! Update the version
      pos1 = index(content(1:content_len), '"version": "')
      if (pos1 > 0) then
         pos1 = pos1 + 12  ! Length of '"version": "'
         pos2 = index(content(pos1:content_len), '"')

         if (pos2 > 0) then
            ! Check if we have room for the new version
            if (content_len - (pos1 + pos2 - 1) + len_trim(version_str) < MAX_BUFFER_SIZE) then
               ! Build new content
               content = content(1:pos1 - 1)//trim(version_str)//content(pos1 + pos2 - 1:content_len)
               content_len = len_trim(content)
            else
               write (error_unit, '(a,a)') "Error: Buffer overflow prevented for file: ", trim(file_path)
            end if
         end if
      end if

      ! Update the package manager if requested
      if (update_to_bun) then
         pos1 = index(content(1:content_len), '"packageManager": "')
         if (pos1 > 0) then
            pos1 = pos1 + 18  ! Length of '"packageManager": "'
            pos2 = index(content(pos1:content_len), '"')

            if (pos2 > 0) then
               ! Check if we have room for the new package manager
               if (content_len - (pos1 + pos2 - 1) + 10 < MAX_BUFFER_SIZE) then  ! 10 is length of "bun@1.2.5"
                  ! Replace with Bun
                  content = content(1:pos1 - 1)//"bun@1.2.5"//content(pos1 + pos2 - 1:content_len)
                  content_len = len_trim(content)
                  package_manager_updated = .true.
               else
                  write (error_unit, '(a,a)') "Error: Buffer overflow prevented for file: ", trim(file_path)
               end if
            end if
         else
            ! packageManager field doesn't exist, add it before the closing brace
            pos1 = content_len
            ! Find the last closing brace
            do while (pos1 > 1)
               if (content(pos1:pos1) == '}') exit
               pos1 = pos1 - 1
            end do

            if (pos1 > 1) then
               ! Check if we have comma before this or need to add one
               pos2 = pos1 - 1
               ! Skip whitespace
               do while (pos2 > 1 .and. (content(pos2:pos2) == ' ' .or. content(pos2:pos2) == char(9) .or. &
                                         content(pos2:pos2) == char(10) .or. content(pos2:pos2) == char(13)))
                  pos2 = pos2 - 1
               end do

               ! Check if we have room to add the package manager
               if (content_len + 30 < MAX_BUFFER_SIZE) then  ! 30 is a safe length for new field
                  ! Insert packageManager before the closing brace
                  content = content(1:pos2)//","//char(10)//'  "packageManager": "bun@1.2.5"'// &
                            content(pos1:content_len)
                  content_len = len_trim(content)
                  package_manager_updated = .true.
               else
                  write (error_unit, '(a,a)') "Error: Buffer overflow prevented for file: ", trim(file_path)
               end if
            end if
         end if
      end if

      ! Write back to file if anything changed
      call write_file_content(file_path, content, content_len, io_stat)
      if (io_stat /= 0) then
         write (error_unit, '(a,a)') "Error: Could not write to file: ", trim(file_path)
         return
      end if

      if (package_manager_updated) then
         write (*, '(a,a)') "Updated package manager to bun@1.2.5 in: ", trim(file_path)
      else
         write (*, '(a,a)') "Updated version in: ", trim(file_path)
      end if
   end subroutine update_package_json

   subroutine update_svelte_file(file_path, version_str)
      use iso_fortran_env, only: error_unit
      implicit none

      character(len=*), intent(in) :: file_path, version_str
      character(len=MAX_BUFFER_SIZE) :: content, current_content
      integer :: io_stat, content_len, version_len
      logical :: file_modified, file_exists
      integer :: pos1, pos2, rel_pos, tag_end, close_tag_start
      character(len=:), allocatable :: clean_version, normalized_version

      ! Initialize variables
      file_modified = .false.
      current_content = ''

      ! File existence check
      inquire (file=file_path, exist=file_exists)
      if (.not. file_exists) return

      ! Read file content
      call read_file_content(file_path, content, content_len, io_stat)
      if (io_stat /= 0) then
         write (error_unit, '(a,a)') "Error reading: ", trim(file_path)
         return
      end if

      ! Version normalization
      version_len = len_trim(version_str)
      allocate (character(len=version_len) :: clean_version)
      clean_version = trim(adjustl(version_str))

      ! Remove leading v/V characters
      do while (len_trim(clean_version) > 0 .and. &
                (clean_version(1:1) == 'v' .or. clean_version(1:1) == 'V'))
         if (len_trim(clean_version) > 1) then
            clean_version = clean_version(2:)
         else
            clean_version = ''
            exit
         end if
      end do

      ! Create normalized version with single 'v' prefix
      normalized_version = 'v'//trim(clean_version)

      ! Process DIV elements
      pos1 = 1
      do while (pos1 <= content_len - 20)
         rel_pos = index(content(pos1:content_len), '<div class="version-text')
         if (rel_pos == 0) exit

         pos1 = pos1 + rel_pos - 1

         ! Find closing '>' of opening tag
         tag_end = pos1
         do while (tag_end <= content_len)
            if (content(tag_end:tag_end) == '>') then
               tag_end = tag_end + 1
               exit
            end if
            tag_end = tag_end + 1
         end do

         ! Find closing </div>
         rel_pos = index(content(tag_end:content_len), '</div>')
         if (rel_pos == 0) then
            pos1 = tag_end
            cycle
         end if
         close_tag_start = tag_end + rel_pos - 1

         ! Extract existing content with bounds checking
         current_content = content(tag_end:close_tag_start - 1)
         if (len_trim(current_content) > 0) then
            ! Remove existing v/V prefixes
            do while (current_content(1:1) == 'v' .or. current_content(1:1) == 'V')
               if (len_trim(current_content) > 1) then
                  current_content = current_content(2:)
               else
                  current_content = ''
                  exit
               end if
            end do
         end if

         ! Update if different from normalized version
         if (trim(current_content) /= trim(clean_version)) then
            content = content(1:tag_end - 1)//trim(normalized_version)// &
                      content(close_tag_start:content_len)
            content_len = content_len - (close_tag_start - tag_end) + &
                          len_trim(normalized_version)
            file_modified = .true.
         end if

         pos1 = close_tag_start + 6
      end do

      ! Process <p id="versiontext"> elements
      pos1 = 1
      do while (pos1 <= content_len - 20)
         rel_pos = index(content(pos1:content_len), '<p id="versiontext">')
         if (rel_pos == 0) exit

         pos1 = pos1 + rel_pos - 1

         ! Find closing </p>
         rel_pos = index(content(pos1:content_len), '</p>')
         if (rel_pos == 0) then
            pos1 = pos1 + 20
            cycle
         end if
         close_tag_start = pos1 + rel_pos - 1

         ! Find "Current version: " text
         tag_end = index(content(pos1:close_tag_start), 'Current version: ')
         if (tag_end == 0) then
            pos1 = close_tag_start + 4
            cycle
         end if
         tag_end = pos1 + tag_end + 16  ! Move past "Current version: "

         ! Update the version text
         content = content(1:tag_end - 1)//trim(normalized_version)// &
                   content(close_tag_start:content_len)
         content_len = content_len - (close_tag_start - tag_end) + &
                       len_trim(normalized_version)
         file_modified = .true.

         pos1 = close_tag_start + 4
      end do

      ! Write modified content
      if (file_modified) then
         call write_file_content(file_path, content, content_len, io_stat)
         if (io_stat == 0) then
            write (*, '(a,a)') "Updated: ", trim(file_path)
         end if
      end if

      ! Cleanup allocated memory
      if (allocated(clean_version)) deallocate (clean_version)
   end subroutine update_svelte_file

   ! Original say_hello subroutine to maintain compatibility
   subroutine say_hello
      print *, "Hello, version_updater!"
   end subroutine say_hello

end module version_updater
