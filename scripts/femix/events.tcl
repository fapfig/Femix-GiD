###############################################################################
# events.tcl --
#
# GiD-FEMIX problem type.
#
# This file contains the events (or commands) associated to the controls, 
# i.e. menus, toolbars, etc.
# 
###############################################################################

namespace eval Event {}

# It is called when the project is about to be closed.
# 
proc Event::EndProblemtype {} {
    # New event system need an unregister
    if {[GidUtils::VersionCmp "14.1.4d"] >= 0 } {
        GiD_UnRegisterEvents PROBLEMTYPE Femix
    }

    # Clear femix variable.
    if {[array exists ::Femix::femixVars]} {
        # Clear private global variable
        unset -nocomplain ::Femix::femixVars
    }
}

# It will be called before running the analysis.
# 
# Arguments:
# ----------
# batfilename: The name of the batch file to be run
# basename: The short name model;
# dir: The full path to the model directory;
# problemtypedir: The full path to the Problem Types directory;
# gidexe: The full path to gid;
# args: An optional list with other arguments.
# 
# Return:
# -------
# If it returns -cancel- then the calculation is not started.
# 
proc Event::BeforeRunCalculation {batfilename basename dir problemtypedir gidexe args} {
}

# It will be called just after the analysis finishes.
# 
# Arguments:
# ----------
# basename: the short name model;
# dir: The full path to the model directory;
# problemtypedir: The full path to the Problem Types directory;
# where: Must be local or remote (remote if it was run in a server machine,
#        using ProcServer);
# error: Returns 1 if an calculation error was detected;
# errorfilename: An error filename with some error explanation, or nothing 
#                if everything was ok.
# 
# Return:
# -------
# If it returns -cancel-as a value then the window that inform about the 
# finished process will not be opened.
# 
proc Event::AfterRunCalculation {basename dir problemtypedir where error errorfilename} {
}

# It will be called just before writing the calculation file. It is useful for 
# validating some parameters.
# 
# Arguments:
# ----------
# file: The name of the output calculation file.
# 
# Return:
# -------
# If it returns -cancel- as a value then nothing will be written.
# 
proc Event::BeforeWriteCalculationFile {file} {
    Femix::CreatePosBat
}

# It will be called just after the analysis finishes.
# 
# Arguments:
# ----------
# filename: the name of the output calculation file 
# error: an error code if there is some problem writing the output calculation file.
# 
# Return:
# -------
# If it returns -cancel- as a value then the calculation is not invoked.
# 
proc Event::AfterWriteCalculationFile {filename error} {
    set err [catch { Writer::WriteInputFile $filename } ret]
    if { $err } {       
        WarnWin [= "Error when preparing data for analysis (%s)" $::errorInfo]
        set ret -cancel-
    }
    return $ret
}

# Saves the model data to file.
#
# Arguments:
# ----------
# filename: the name of the output calculation file.
# 
proc Event::WriteInputFile {{filename ""}} {  
    if {$filename eq ""} {
        if {[Femix::IsModelSaved] == 1} {
            # Sets the femix_gl.dat file name.
            set filename [file join [GiD_Info Project Modelname].gid [Femix::GetModelName]_gl.dat]
            Writer::WriteInputFile $filename
        }
    } 
}

# Run femix executables.
# 
# Arguments:
# ----------
# app: name of the executable, it can be prefemix, femix or posfemix.
#
proc Event::RunExec {app} {
    if {[Femix::IsModelSaved] == 1} {
        # Command to run.
        set bin [file join $::Femix::femixVars(Path) bin $app.exe]
        exec cmd /c start cmd /k $bin [Femix::GetJob]
    }
}

# About Femix splash dialog.
# 
proc Event::About {} {
    set splash [GiD_Set SplashWindow]
    GiD_Set SplashWindow 1 ; # Set temporary to 1 to force show splash without take care of the GiD splash preference
    set offX 310
    set fnt "Sans 10"
    if { $::tcl_platform(platform) == "windows" } {
        set fnt "verdana 10"
        set offX 310
    }
    set line1 "Version: $::Femix::femixVars(Version)"
    ::GidUtils::Splash [file join $::Femix::femixVars(Path) images splash.png] .splash 0 [list $line1 $offX 300]


    .splash.lv configure -font $fnt -background white -foreground black -relief solid -borderwidth 1 -padx 12 -pady 3
    update
    
    GiD_Set SplashWindow $splash
}

# Clear all femix files from the project directory.
# 
proc Event::CleanProject {} { 
    set dir [Femix::GetProjecDir]
    # List of extensions that will be deleted.
    set files {"*_di.pva" "*_gl.dat" "*_ctrl.dat" "*_dr.bin" "_ep.bin" \
               "*_gl.bin" "*_ep.bin" "*_se.pva" "*_sa.pva" "*_me.s3d" \
               "*_um.s3d" "*_dm.s3d" "*.post.msh" "*.post.res"}

    set answer [tk_messageBox -message "Do you wanna clean the project folder?\nOnly Femix files will be deleted." -type yesno -icon question]
    switch -- $answer {
    yes {
        try {
            # Delete all files.
            foreach ext $files {
                file delete {*}[glob -nocomplain [file join $dir $ext]]
            }
        } on error {msg} {
        WarnWin "It was not possible to clean the project because some files may be in use.\nPlease re-open GiD and try again."
        }
    }
    no {}
    }
}

# Exports the mesh only.
proc Event::ExportMesh {{filename ""}} {  
    if {$filename eq ""} {
        if {[Femix::IsModelSaved] == 1} {
            # Sets the femix_gl.dat file name.
            set filename [file join [GiD_Info Project Modelname].gid [Femix::GetModelName].mesh]
            Export::ExportMesh $filename
        }
    } 
}

proc Event::OpenFemix {} {
    set file [Browser-ramR file read .gid [= "Read FEMIX file"] {} {{{FEMIX} {*_gl.dat }}} {} 0 {}]
    if { $file != "" } {
        # Open a new gid project
        GiD_Process Mescape Files New
    }
}

proc Event::ReadResults {cmd} {
    if {$cmd == "dipva"} { set error [Import::PvaResults "di" "me"]}
    if {$cmd == "sepva"} { set error [Import::PvaResults "se" "um"] }
    if {$cmd == "sapva"} { set error [Import::PvaResults "sa" "um"] }

    if {$error == 0} {
        # Activates the postprocessing environment.
        GiD_Process Mescape Postprocess
        # Open the result file.
        GiD_Process Mescape Files Read $Import::resFilename
    }    
}

proc Event::ImportPva {} {
    set file [Browser-ramR file read .gid [= "Read PVA file"] {} {{{FEMIX} {*.pva }}} {} 0 {}]
    if { $file != "" } {
        set filename [file tail $file]
        set last [string last "_" $filename]
        set rtype [string range $filename [expr $last+1] [expr $last+2]]

        if {$rtype == "di"} {
            set mesh "me"
        } else {
            set mesh "um"
        }

        # Imports the file
        set error [Import::PvaResults $rtype $mesh $file]
        if {$error == 0} {
            # Activates the postprocessing environment.
            GiD_Process Mescape Postprocess
            # Open the result file.
            GiD_Process Mescape Files Read $Import::resFilename
        }
    }
}

# Procedure used for testing during development.
# This event is dispatched when the user clicks on the menu Femix->Test.
# This menu is only available in dev mode.
# 
proc Event::Debug {} {
    set elConn [GiD_Mesh get element 1 connectivities]
    set elName [GiD_Mesh get element 1 connectivities]

    # WarnWin "Fixed: [Femix::GetConn 1]\n\nOriginal: $elConn"

    set f1 [GiD_WriteCalculationFile elements -return -elemtype Hexahedra -elements_faces faces \
     [dict create  "Face Loads Auto1" "Auto 1 element id:%d face index:%d "]]
    set f2 [GiD_WriteCalculationFile elements -return -elemtype Hexahedra -elements_faces faces \
     [dict create  "Face Loads Auto2" "Auto 2 element id:%d face index:%d "]]
    set f3 [GiD_WriteCalculationFile elements -return -elemtype Hexahedra -elements_faces faces \
     [dict create  "Face Loads Auto3" "Auto 3 element id:%d face index:%d "]]
    set f4 [GiD_WriteCalculationFile elements -return -elemtype Hexahedra -elements_faces faces \
     [dict create  "Face Loads Auto4" "Auto 4 element id:%d face index:%d "]]
    set f5 [GiD_WriteCalculationFile elements -return -elemtype Hexahedra -elements_faces faces \
     [dict create  "Face Loads Auto5" "Auto 5 element id:%d face index:%d "]]
    set f6 [GiD_WriteCalculationFile elements -return -elemtype Hexahedra -elements_faces faces \
     [dict create  "Face Loads Auto6" "Auto 6 element id:%d face index:%d "]]


    WarnWin "$f1\n$f2\n$f3\n$f4\n$f5\n$f6"
}

proc Event::ModifyPreferencesWindow { root } {
    if {[info exists ::Femix::femixVars(Path)]} {
        set findnode [$root find "name" "general"]
        if { $findnode != "" } {
            set xml_preferences_filename [file join $::Femix::femixVars(Path) xml preferences.xml]
            set xml_data [GidUtils::ReadFile $xml_preferences_filename] 
            CreateWidgetsFromXml::AddAfterName $root "general" $xml_data 
            CreateWidgetsFromXml::UpdatePreferencesWindow
        }
    }
    return 0
}

# Preference dialog events
# This function is called when the preference dialog is activated.
# 
proc Event::ManagePreferences { cmd name {value ""}} {
    set ret ""

    switch $cmd {
        "GetValue" {
            if {[info exists ::Femix::femixVars($name)]} {
                set ret $::Femix::femixVars($name)
            } else {
                set ret [Event::ManagePreferences GetDefaultValue $name]
            }
        }
        "SetValue" {
            if {$name eq "DevMode"} { 
                set ::Femix::femixVars($name) $value
            }
            if {$name eq "RenumberMethod"} {
                set ::Femix::femixVars($name) $value
                GiD_Process Mescape Utilities Variables RenumberMethod $value escape
            }
        }
        "GetDefaultValue" {
            switch $name {
                "DevMode" { set ret "release" }
                "RenumberMethod" { set ret "0" }
            }
        }
    }

    return $ret
}