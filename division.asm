sys_write	equ	1		; the linux WRITE syscall
sys_exit	equ	60		; the linux EXIT syscall
sys_stdout	equ	1		; the file descriptor for standard output (to print/write to)

section .data
	linebreak	db	0x0A	; ASCII character 10, a line break \n
    message db "Частное = %d  Остаток = %d", 10, 0

section .text
global _start
extern printf
_start:
	pop	r8			; pop the number of arguments from the stack
	pop	rsi			; discard the program name, since we only want the commandline arguments
    cmp	r8,	3       ; check if we have to print 2 arguments
    jnz	exit		; if not, jump to the 'end' label

top:
	; loop condition
	cmp	r8,	1		        ; check if we have to print more arguments
	jz	divisionfunc		; if not, jump to the 'end' label

    ; get length in edx
    xor rdx, rdx ; clear rdx register
    pop rcx ; get first arg
getlen:
    cmp byte [rcx + rdx], 0 ; if byte is 0x00 then it is end of argument 
    jz gotlen
    inc rdx ; if not then increment rdx register
    jmp getlen

; print the argument
gotlen:
    mov rsi, rcx ; move a pointer to the string we want to print from the stack
	mov	rax,	sys_write	; set the rax register to the syscall number we want to execute (WRITE)
	mov	rdi,	sys_stdout	; specify the file we want to write to (standard output in this case)
	;mov	rdx,	length		; specify the (fixed) length of the string we want to print
	syscall				; execute the system call
	call string_to_int ; convert string to int
continue:
	; print a newline
	mov	rax,	sys_write	; rax is overwritten by the kernel with the syscall return code, so we set it again
	mov	rdi,	sys_stdout 
	mov	rsi,	linebreak	; this time we want to print a line break
	mov	rdx,	1		; which is one byte long
	syscall
	
	dec	r8			; count down every time we print an argument until there are none left
	jmp	top			; jump back to the top of the loop

divisionfunc: ; here will be division algo
    ; r13/r12
    mov rdx, r13 ; делимое
    mov rbx, r12 ; делитель
    xor r12, r12

    bsr rcx,rdx ; bsr - номер первого старшего установленного бита заносится в указанный в команде регистр, иначе zf=1
    bsr rax,rbx 
    sub rcx,rax  ;rcx - число циклов как разность между разрядностями
    jnc polozhit ; если делимое меньше делителя
    mov rax, 0   ; то частное равно нулю
    mov r9, rdx  ; и остаток равен делимому
    jmp end_of_cycle;
polozhit:
    mov rbp,1 ; эта единичка будет скользить по числу
    shl rbp,cl ; сдвиг на младшую часть разности разрядностей
    shl rbx,cl ; сдвиг делителя на младшую часть разности разрядностей
    xor rax,rax; в RAX место под частное, в RDX - остаток
    or rsi,-1 ; rsi = 0xffffffffffffffff или -1
cycle: 
    mov rdi,rbx ; rdi - хранилище делителя, который скользит вдоль числа
    add rdi, rsi
    xor rdi, rsi; neg rdi
    add rdx, rdi; если rsi=-1 тогда rdx:=rdx-rbx иначе rdx:=rdx+rbx
    ;carry flag - > сохраняем остаток от деления
    jnc without_save
    mov r9, rdx 
    ;
without_save:
    sbb rsi, rsi; если CF=1 тогда rsi:=-1 иначе rsi:=0
    mov rdi, rsi
    and rdi, rbp; если rsi=-1 тогда rdi:=rbp иначе rdi:=0
    add rax, rdi; если rsi=-1 тогда rax:= rax + rbp
    test rdx, rdx
    jz end_of_cycle
    shr rbx, 1 ; сдвигаем делитель вдоль числа
    shr rbp, 1 ; если цикл деления возможен, единичка регистра rbp, идущая вдоль числа, прибавится к частному rax
    jnz cycle

end_of_cycle: 
    mov rdx, r9
    xor r9, r9
    ;в RAX место под частное, в RDX - остаток
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov rdi, message ;
    mov rsi, rax
    mov rax, 0
    call printf
    add rsp, 16
    mov rsp, rbp
    pop rbp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:
;; RAX = integer value to convert
;; RSI = pointer to buffer to store the string in (must have room for at least 10 bytes)
;; Output:
;; RAX = pointer to the first character of the generated string
;int_to_string:
;  add rsi,9
;  mov byte [rsi],STRING_TERMINATOR
;  mov ebx,10         
;next_digit_in_str:
;  xor rdx,rdx         ; Clear rdx prior to dividing rdx:rax by rbx
;  div rbx             ; rax /= 10
;  add dl,'0'          ; Convert the remainder to ASCII 
;  dec rsi             ; store characters in reverse order
;  mov [rsi],dl
;  test rax,rax            
;  jnz next_digit_in_str     ; Repeat until rax==0
;  mov rax,rsi
;  ret


; the program is finished, now exit cleanly by calling the EXIT syscall
exit:
	mov	rax,	sys_exit	; load the EXIT syscall number into rax
	mov	rdi,	0		; the program return code
	syscall				; execute the system call

string_to_int: ; rsi has pointer to the string in stack, need to copy byte by byte and convert it 
    ;rdx is a counter of len
    mov r13, r12 ; here will lay first argument; in r12 will lay second argument
	xor r12, r12 ; clear preveous int
    mov r9, rdx
next_digit:
    xor rax, rax
    xor rcx, rcx
    lea rcx, [rsi+r9] ; there we will go byte by byte on argument in stack
    sub rcx, rdx
    mov al, [rcx]; copy first byte of argument (2 in decimal = 32 in ascii)
    sub al,'0'    ; convert from ASCII to number
    ;imul r12,10 ; using calculated number to add it to end answer with multiply func, need to be removed 
    mov r10, r12
    shl r10, 1
    xor r12, r12
    add r12, r10
    shl r10, 2
    add r12, r10
    ;r12 = r12+"0" + r12+"000" 0b1010
	add r12,rax   ; rbx = rbx*10 + rax
	dec rdx ;  (--rdx)
	jnz next_digit ; if there are more numbers, continue
	ret ; else return 
