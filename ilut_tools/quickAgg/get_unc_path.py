import os


def build_unc_path(in_path):
    
    # based on a network drive path, convert the letter to full machine name
    from pathlib import Path
    unc_path = str(Path(in_path).resolve())
    
    # if the model run folder is on the machine that this script is getting run on,
    # the full machine name path must be manually built.
    if unc_path == in_path:
        import socket
        machine = socket.gethostname()
        drive_letter = os.path.splitdrive(in_path)[0].strip(':')
        folderpath = os.path.splitdrive(in_path)[1]
        unc_path = f"\\\\{machine}\\{drive_letter}{folderpath}"
    
    return unc_path