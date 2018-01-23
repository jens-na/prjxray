# Top-level target for generating a programmable bitstream.  Given a .fasm
# file, calling make with the .fasm extension replaced with .hand_crafted.bit
# will generate a bitstream that includes both the harness and the .fasm design
# ready for programming to a board.  For example, 'make
# roi_noninv.hand_crafted.bit' will generate a bitstream that includes the
# design from roi_noninv.fasm. 
%.hand_crafted.bit: init_sequence.bit %.no_headers.bin final_sequence.bin
	cat $^ > $@

%.no_headers.bin: %.patched.bin
	# WARNING: these values need to be tweaked if anything about the
	# Vivado-generated design changes.
	xxd -p -s 0x18 $< | xxd -r -p - $@

%.patched.bin: %.frm harness_routed.bit
	${XRAY_TOOLS_DIR}/xc7patch \
		--part_file ${XRAY_PART_YAML} \
		--bitstream_file harness_routed.bit \
		--frm_file $< \
		--output_file $@

# xc7patch currently only generates the actual frame writes which is
# insufficient to program a device.  Grab the initialization and finalization
# sequences from the harness bitstream so they can be tacked on to the
# xc7patch-generated bitstream to create a programmable bitstream.
#
# The offsets used below were determined by manually inspecting
# harness_routed.bit with a hex editor.  init_sequence.bit is the beginning of
# the file until just before the actual frame data is sent via a write to FDRI.
# final_sequence.bin is from just after the frame data write to the end of the
# file.  Note that final_sequence.bin normally includes at least one CRC check.
# The sed command replaces any CRC checks with a Reset CRC command which is the
# same behavior as setting BITSTREAM.GENERAL.CRC to Disabled.  These offset
# should not change unless you alter the bitstream format used (i.e. setting
# BITSTREAM.GENERAL.DEBUGBITSTREAM or BITSTREAM.GENERAL.PERFRAMECRC to YES).
init_sequence.bit: harness_routed.bit
	# WARNING: these values need to be tweaked if anything about the
	# Vivado-generated design changes.
	xxd -p -l 0x147 $< | xxd -r -p - $@

final_sequence.bin: harness_routed.bit
	# WARNING: these values need to be tweaked if anything about the
	# Vivado-generated design changes.
	xxd -p -s 0x216abf $< | \
		tr -d '\n' | \
		sed -e 's/30000001.\{8\}/3000800100000007/g' | \
		fold -w 40 | \
		xxd -r -p - $@

# Generate a suitable harness by using Vivado's partial reconfiguration
# feature.  roi_inv is used as a sample reconfiguration design as one is
# required to generate a partial reconfiguration design.
harness.dcp: harness.tcl top.v roi_base.v
	vivado -mode batch -source harness.tcl

roi_inv.dcp: roi_inv.tcl roi_inv.v
	vivado -mode batch -source roi_inv.tcl

roi_inv_routed.dcp roi_inv_w_harness_routed.dcp harness_routed.dcp: harness.dcp roi_inv.dcp roi_inv_routed.tcl
	vivado -mode batch -source roi_inv_routed.tcl

# Conversions between various formats.
%.bit: %.dcp write_bitstream.tcl
	vivado -mode batch -source write_bitstream.tcl -tclargs $< $@

%.bits: %.bit
	${XRAY_BITREAD} -y -o $@ $<

# Extract only bits that are within the ROI.
%.roi.bits: %.bit
	${XRAY_BITREAD} -F ${XRAY_ROI_FRAMES} -z -y -o $@ $<

%.segp: %.roi.bits
	${XRAY_SEGPRINT} -zd $< > $@

%.fasm: %.segp
	${XRAY_DIR}/tools/segprint2fasm.py $< $@

%.frm: %.fasm
	${XRAY_DIR}/tools/fasm2frame.py $< $@

# This format is a human-readable representation of the configuration packets
# used to interact with 7-series chips over JTAG.
%.packets: %.bit
	${XRAY_TOOLS_DIR}/bittool list_config_packets $< > $@

clean:
	rm -rf specimen_[0-9][0-9][0-9]/ seg_clblx.segbits vivado*.log vivado_*.str vivado*.jou design *.bits *.dcp *.bit design.txt .Xil
	rm -rf out_* *~
	rm -rf *.frm *.segp *.packets *.bin
	rm -rf harness_routed.fasm roi_inv_w_harness_routed.fasm
	rm -rf hd_visual

.PHONY: clean
