# Example pre-req
# ./runme.sh
# XRAY_ROIV=roi_inv.v XRAY_FIXED_XDC=out_xc7a35tcpg236-1_BASYS3-SWBUT_roi_basev/fixed_noclk.xdc ./runme.sh

set -ex

fasm_in=$1
if [ -z "$fasm_in" ] ; then
    echo "need .fasm arg"
    exit
fi
bit_in=$2
if [ -z "$bit_in" ] ; then
    echo "need .bit arg"
    exit
fi
bit_out=$3
if [ -z "$bit_out" ] ; then
    bit_out=$(echo $fasm_in |sed s/.fasm/.bit/)
    if [ "$bit_out" = "$fasm_in" ] ; then
        echo "Expected fasm file"
        exit 1
    fi
fi

echo "Design .fasm: $fasm_in"
echo "Harness .bit: $bit_in"
echo "Out .bit: $bit_out"

${XRAY_DIR}/tools/fasm2frame.py $fasm_in roi_partial.frm

${XRAY_TOOLS_DIR}/xc7patch \
	--part_file ${XRAY_PART_YAML} \
	--bitstream_file $bit_in \
	--frm_file roi_partial.frm \
	--output_file patched.bin

# WARNING: these values need to be tweaked if anything about the
# Vivado-generated design changes.
xxd -p -l 0x147 $bit_in | xxd -r -p - init_sequence.bit

# WARNING: these values need to be tweaked if anything about the
# Vivado-generated design changes.
xxd -p -s 0x18 patched.bin | xxd -r -p - no_headers.bin

# WARNING: these values need to be tweaked if anything about the
# Vivado-generated design changes.
xxd -p -s 0x216abf $bit_in | \
	tr -d '\n' | \
	sed -e 's/30000001.\{8\}/3000800100000007/g' | \
	fold -w 40 | \
	xxd -r -p - final_sequence.bin

cat init_sequence.bit no_headers.bin final_sequence.bin >$bit_out

#openocd -f $XRAY_DIR/utils/openocd/board-digilent-basys3.cfg -c "init; pld load 0 $bit_out; exit"

