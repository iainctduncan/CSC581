# python script for setting up a new tune

import sys
import os
import shutils
import pdb

dry_run = False
#dry_run = True

def do(command):
    print(command)
    if not dry_run:
        os.system(command)

if __name__=="__main__":
    name = sys.argv[1]
    src = "new"
    dest = f"{name}"
    cwd = os.getcwd()

    print("creating new tune '%s'" % name)

    do( f"mkdir {dest}" )

    print("copying files")
    for filename in os.listdir(src):
        if filename[0] == ".":
            continue
        dest_filename = filename.replace("NAME", name)
        do( f"cp -rp {src}/{filename} {dest}/{dest_filename}" )

    print("patching files")
    do( f"perl -pi -e 's|NAME|{name}|g' {dest}/*.scm" )

    print("copying and renaming Live project")
    do( f"cp -rp new/s4m-new\ Project {dest}/{name}\ Project")
    do( f"mv {dest}/{name}\ Project/s4m-new.als {dest}/{name}\ Project/{name}.als")

    # patch the save dir string in the main file to be correct dir
    print("patching in savedir")
    save_dir = f"{cwd}/{name}/data"
    do( f"perl -pi -e \"s|SAVEDIR|{save_dir}|\" {dest}/{name}-main.scm")

    # patch the vim script
    print("patching the vim session file")
    do( f"perl -pi -e \"s|NAME|{name}|g\" {dest}/{name}.vim")

    print("DONE")
