# Minimal sc_manifest.tcl for basic PPA analysis
# This file provides stub implementations for sc_cfg_* functions

# Define basic configuration functions as stubs
proc sc_cfg_exists {args} {
    # Return false for all configuration checks
    return 0
}

proc sc_cfg_get {args} {
    # Return empty for all configuration requests
    return {}
}

proc sc_cfg_tool_task_exists {args} {
    # Return false for all tool task checks  
    return 0
}

proc sc_cfg_tool_task_get {args} {
    # Return empty list for all tool task requests
    return {}
}

# Define empty configuration dictionaries
set sc_cfg_dict {}
set sc_tool_dict {}

puts "sc_manifest.tcl loaded - basic stub mode for PPA analysis" 