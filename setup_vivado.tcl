 # ============================================================
# Script TCL para configurar proyecto de Vivado RISC-V Pipeline
# ============================================================
# USO:
#   1. Abre Vivado
#   2. En la Tcl Console, ejecuta:
#      source C:/Users/anyel/OneDrive/Desktop/pipeline/setup_vivado.tcl
# ============================================================

# Directorio donde están los archivos fuente
set source_dir "C:/Users/anyel/OneDrive/Desktop/pipeline"

# Configuración del proyecto
set project_name "riscv_pipeline"
set project_dir "C:/VivadoProjects/riscv_pipeline"

# Crear directorio del proyecto si no existe
file mkdir $project_dir

# Crear o abrir proyecto
if {[file exists "$project_dir/$project_name.xpr"]} {
    puts "Abriendo proyecto existente..."
    open_project "$project_dir/$project_name.xpr"
} else {
    puts "Creando nuevo proyecto..."
    create_project $project_name $project_dir -part xc7a35tcpg236-1 -force
}

# Remover archivos antiguos si existen
if {[llength [get_files -of_objects [get_filesets sources_1]]] > 0} {
    puts "Removiendo archivos antiguos..."
    remove_files [get_files -of_objects [get_filesets sources_1]]
}

# Agregar TODOS los archivos fuente Verilog
puts "Agregando archivos fuente..."
add_files -fileset sources_1 [list \
    [file normalize "$source_dir/top.v"] \
    [file normalize "$source_dir/riscvpipeline.v"] \
    [file normalize "$source_dir/datapath.v"] \
    [file normalize "$source_dir/controller.v"] \
    [file normalize "$source_dir/hazard_unit.v"] \
    [file normalize "$source_dir/maindec.v"] \
    [file normalize "$source_dir/aludec.v"] \
    [file normalize "$source_dir/regfile.v"] \
    [file normalize "$source_dir/extend.v"] \
    [file normalize "$source_dir/alu.v"] \
    [file normalize "$source_dir/adder.v"] \
    [file normalize "$source_dir/imem.v"] \
    [file normalize "$source_dir/dmem.v"] \
    [file normalize "$source_dir/flopr.v"] \
    [file normalize "$source_dir/mux2.v"] \
    [file normalize "$source_dir/mux3.v"] \
    [file normalize "$source_dir/mux_df.v"] \
    [file normalize "$source_dir/IF_ID.v"] \
    [file normalize "$source_dir/ID_EX.v"] \
    [file normalize "$source_dir/EX_MEM.v"] \
    [file normalize "$source_dir/MEM_WB.v"] \
]

# Agregar testbench si existe
if {[file exists "$source_dir/testbench.v"]} {
    puts "Agregando testbench..."
    add_files -fileset sim_1 [file normalize "$source_dir/testbench.v"]
}

# Establecer top module
set_property top top [current_fileset]

# Actualizar orden de compilación
puts "Actualizando orden de compilación..."
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Configurar simulación
set_property target_simulator XSim [current_project]
set_property -name {xsim.simulate.runtime} -value {1000ns} -objects [get_filesets sim_1]

puts ""
puts "=========================================="
puts "Proyecto configurado exitosamente!"
puts "=========================================="
puts "Ubicación: $project_dir/$project_name.xpr"
puts "Top module: top"
puts "Total archivos: [llength [get_files -of_objects [get_filesets sources_1]]]"
puts "=========================================="

