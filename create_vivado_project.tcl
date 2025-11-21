# Script TCL para crear proyecto de Vivado
# Ejecutar en Vivado: source create_vivado_project.tcl
# IMPORTANTE: Ejecutar este script desde el directorio donde están los archivos .v

# Obtener directorio actual donde están los archivos fuente
set source_dir [pwd]

# Configuración del proyecto
# IMPORTANTE: Crear proyecto fuera de OneDrive para evitar problemas de permisos
set project_name "riscv_pipeline"
# Usar ubicación local fuera de OneDrive
set project_dir "C:/VivadoProjects/riscv_pipeline"
# Alternativa: usar carpeta temporal
# set project_dir "C:/temp/vivado_project"

# Crear directorio del proyecto si no existe
file mkdir $project_dir

# Crear proyecto
create_project $project_name $project_dir -part xc7a35tcpg236-1 -force

# Cambiar al directorio de fuentes para agregar archivos
cd $source_dir

# Agregar archivos fuente Verilog usando rutas absolutas
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

# Agregar testbench si se necesita para simulación
if {[file exists "$source_dir/testbench.v"]} {
    add_files -fileset sim_1 [file normalize "$source_dir/testbench.v"]
}

# Establecer top module
set_property top top [current_fileset]

# Actualizar archivos de compilación
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Configurar simulación (opcional)
set_property target_simulator XSim [current_project]
set_property -name {xsim.simulate.runtime} -value {1000ns} -objects [get_filesets sim_1]

puts "Proyecto de Vivado creado exitosamente: $project_dir/$project_name.xpr"
puts "Puedes abrir el proyecto con: open_project $project_dir/$project_name.xpr"


