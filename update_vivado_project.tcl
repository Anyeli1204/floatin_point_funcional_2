# Script TCL para actualizar proyecto existente de Vivado
# Ejecutar en Vivado: source update_vivado_project.tcl
# IMPORTANTE: Abrir el proyecto primero antes de ejecutar este script

# Directorio donde están los archivos fuente
set source_dir "C:/Users/anyel/OneDrive/Desktop/pipeline"

# Directorio del proyecto
set project_dir "C:/VivadoProjects/riscv_pipeline"
set project_name "riscv_pipeline"

# Abrir proyecto si no está abierto
if {[current_project -quiet] == ""} {
    open_project "$project_dir/$project_name.xpr"
}

# Remover todos los archivos existentes del fileset
remove_files [get_files -of_objects [get_filesets sources_1]]

# Agregar todos los archivos fuente Verilog actualizados
# Archivos principales del pipeline
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

# Actualizar orden de compilación
update_compile_order -fileset sources_1

# Establecer top module
set_property top top [current_fileset]

puts "Proyecto actualizado exitosamente!"
puts "Todos los archivos han sido refrescados desde: $source_dir"

