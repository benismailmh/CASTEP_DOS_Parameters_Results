#!/bin/bash
#SBATCH -J combined_dos
#SBATCH --ntasks=4
#SBATCH --ntasks-per-core=1
#SBATCH --partition=mediumq
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

sg castepgroup

# Load necessary modules
module load intel2021/mpi intel2021/mkl intel2021/compiler lapack/gcc/64/3.9.0 blas/gcc/64/3.8.0
module load Python/3.11.3-GCCcore-12.3.0
module load matplotlib/3.5.2-foss-2022a
module load py-numpy-1.21.3-gcc-10.2.0-kda66ta
module load gnuplot
module load CASTEP/24.1

# Arrays for BASIS_PRECISION and kpoint_mp_grid values
precisions=("coarse" "medium" "fine" "precise")
kpoints=("1 1 1" "1 1 2" "2 2 2" "2 2 4" "3 3 3" "3 3 6" "4 4 8" "4 4 4")

# Nested loop through kpoints and precisions
for kpoint in "${kpoints[@]}"; do
    for precision in "${precisions[@]}"; do
        echo "Running calculation for kpoint: $kpoint and BASIS_PRECISION: $precision"

        # Create folder structure
        kpoint_label=$(echo "$kpoint" | tr ' ' '_')
        folder_name="kpoint_${kpoint_label}_precision_${precision}"
        mkdir -p "$folder_name"

        # Create .cell file
        cat > CsSnXI3.cell << EOF
%BLOCK lattice_cart
   ANG
13.3682743315314 0 0
0 13.3683574080951 0
0 0 6.04792174368072    
%ENDBLOCK lattice_cart

%BLOCK positions_frac
   Sn               0.000000430537850       0.000000441575864      -0.000000080346865
   Sn               0.000000374980549       0.499998711990897       0.000000018872012
   Sn               0.499998711498074       0.000000437537312       0.000000058830007
   Sn               0.499998705923461       0.499998718746543      -0.000000039216399
   I                0.249998378052443       0.000000294324172      -0.000000074614162
   I               -0.000000318747420      -0.000000281698495       0.499999825033262
   I                0.000000291940948       0.249998350405879       0.000000078898932
   I                0.249998403710143       0.499997545522631      -0.000000239814543
   I               -0.000000342106026       0.499997855673540       0.500000084228929
   I                0.000000325769484       0.749996556586292       0.000000092020633
   I                0.749996620829655       0.000000412493212      -0.000000147856841
   I                0.499997972950724      -0.000000297684473       0.500000046949994
   I                0.499997611585538       0.249998385175622       0.000000082836424
   I                0.749996661228501       0.499997575278938       0.000000124621699
   I                0.499997905197403       0.499997869342292       0.500000069340457
   I                0.499997691247884       0.749996617950102      -0.000000040027819
   Cs               0.249999345867713       0.249999283250070       0.500000225763966
   Cs               0.249999100585671       0.749997325804735       0.500000055488240
   Cs               0.749997182337010       0.249999100169935       0.500000156214872
   Cs               0.749996946610395       0.749997097554929       0.499999702777202
%ENDBLOCK positions_frac

kpoint_mp_grid : $kpoint
EOF

        # Create .param file
        cat > CsSnXI3.param << EOF
TASK                   : SPECTRAL
SPECTRAL_TASK          : DOS
BASIS_PRECISION        : $precision
XC_FUNCTIONAL          : PBE
EOF

        # Create .odi file
        cat > CsSnXI3.odi << EOF
TASK              : dos
EFERMI            : optados
compute_band_gap  : TRUE
set_efermi_zero   : TRUE
EOF

        # Run CASTEP
        echo "Running CASTEP for $kpoint and $precision"
        castep.mpi CsSnXI3

        # Run OptaDOS
        echo "Running OptaDOS for $kpoint and $precision"
        optados.mpi CsSnXI3

        # Move files to folder
        for file in CsSnXI3*; do
            mv "$file" "$folder_name/${file}"
        done

        # Generate plot with Gnuplot
        gnuplot <<EOF
        set terminal pngcairo size 800,600 enhanced font 'Arial,12'
        set output '$folder_name/dos_plot_${kpoint_label}_${precision}.png'
        set datafile commentschars "#"
        set xlabel "Energy (eV)"
        set ylabel "DOS (electrons per eV)"
        set title "DOS for kpoint $kpoint and BASIS_PRECISION $precision"
        set xrange [-5:5]
        set yrange [0:100]
        set xtics -5,1,5
        set ytics 0,20,100
        set style line 1 lt 2 lw 2 lc rgb "blue"
        set arrow from 0,0 to 0,100 nohead dashtype 2 lc rgb "red"
        plot '$folder_name/CsSnXI3.adaptive.dat' using 1:2 with lines linestyle 1 title "DOS"
EOF
    done
done
