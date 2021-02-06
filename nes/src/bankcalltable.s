.export bankcall_table

.macro bankcall_entry callid, entrypoint
  .exportzp callid
  .import entrypoint
  callid = <(*-bankcall_table)
  .out .string(callid)
  .addr entrypoint-1
  .byt <.bank(entrypoint)
.endmacro

.segment "RODATA"
; Each of these macros takes three arguments:
; the external name of the method (loaded into X before bankcall),
; which bank the method is in,
; and the entry point within the bank.
bankcall_table:
  bankcall_entry load_continue_chr,          load_continue_chr_far

