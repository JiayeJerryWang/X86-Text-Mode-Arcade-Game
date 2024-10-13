# mp1.S - missile-command version
# Good luck, and have fun!
 
.data
   
    # Constants for accessing the fields of a struct missile,
    # struct missile is defined in rtc.h and mp1.h
 
    NEXT      = 0
    X     = 4
    Y     = 8
    VX    = 12
    VY    = 16
    DEST_X    = 20
    DEST_Y    = 24
    EXPLODED  = 28
    C     = 32
 
    # Character to draw for an explosion - '@'
 
    EXPLOSION = 64
     
# Data shared between this file and rtc.c helper functions
 
# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score
 
mp1_missile_list:   .long 0x0   # Head of list pointer
base_alive:     .long 0x0   # Array of 3 bytes, plus a padding byte
mp1_score:      .long 0x0   # Player's current score
address: .long 0x0
 
# Data private to this  file
 
base_pic:           .string "/^^^\\"    # Picture of a live base
dead_base_pic:      .string "xxxxx" # Picture of a dead base
crosshairs_x:       .long 0x0   # X-position of the crosshairs
crosshairs_y:       .long 0x0   # Y-position of the crosshairs
 
.text
 
# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX
 
mp1_poke:
        movl    vmem_base_addr(,1),%edx
        movb    %cl,(%edx,%eax,1)
        ret
 
#   ----------------- Exported functions ---------------------
 
# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#   (1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#   (2) Redraw the bases - they may have been overwritten with missiles
#   (3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention
 
.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
    pushl %ebp
    movl %esp, %ebp
 
    pushl %ebx #protect callee-saved registers
    pushl %esi
    pushl %edi
 
    call update_missiles
    call update_cities
    call update_crosshairs
 
    popl %edi
    popl %esi
    popl %ebx
    leave
    ret
 
# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention
 
.globl mp1_ioctl
mp1_ioctl:
    movl 8(%esp), %ebx # store the cmd value into ebx
    cmpl $0, %ebx # check if cmd value < 0
    jl invalid_command
    cmpl $4, %ebx
    jg invalid_command # check if cmd value > 4
    imull $4, %ebx # each cmd value holds 4 bytes
    jmp *jumptable(%ebx) # jump to jumptable + 4 * cmd value
    ret
 
    invalid_command:
        movl $-1, %eax
        ret
 
    jumptable:
        .long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame
 
# ----------------- Functions private to this file -------------------
# ----------------- 1st operation: update missiles -------------------
 
update_missiles:
    pushl %ebp
    movl %esp, %ebp
 
    pushl %ebx #protect callee-saved registers
    pushl %esi
    pushl %edi
 
    movl mp1_missile_list, %ebx # head of list pointer => ebx
 
    check_list: # check if all the missiles in the list have been updated
        cmpl $0, %ebx
        je all_missiles_updated
 
    check_explode: #check if the missile is exploding
        cmpl $0, EXPLODED(%ebx)
        jne missile_exploded
 
    missile_not_explode: #missile is not exploding, continue to check off_screen and reach_dest
        movl X(%ebx), %esi # x_missile => esi
        movl Y(%ebx), %edi # y_missile => edi
 
    check_off_screen: # 1st check if the missile has moved off of the screen
        sarl $16, %esi # shift 16 bits to store text-mode video location in high 16 bits
        sarl $16, %edi # shift 16 bits to store text-mode video location in high 16 bits
        cmpl $0, %esi # check if x_missile < 0
        jl erase_remove
        cmpl $0, %edi # check if y_missile < 0
        jl erase_remove
        cmpl $79, %esi # check if x_missile > 79
        jg erase_remove
        cmpl $24, %edi # check if y_missile > 24
        jg erase_remove
 
    check_reach_dest: # 2nd check if the missile has reached its destination
        cmpl DEST_X(%ebx), %esi
        jne erase_old_missile # missile not reach dest, redraw
        cmpl DEST_Y(%ebx), %edi
        je missile_exploded # missile reach dest, explode
 
    erase_old_missile: #erase the missile from its old position
        movl X(%ebx), %esi # x_missile => esi
        movl Y(%ebx), %edi # y_missile => edi
        sarl $16, %esi # shift 16 bits to store text-mode video location in high 16 bits
        sarl $16, %edi # shift 16 bits to store text-mode video location in high 16 bits
        imull $2, %esi, %esi # column offset 2
        imull $160, %edi, %edi # row offset 160
        addl %esi, %edi # offset from the start of video memory
        movl %edi, %eax # move the offset into eax
        movb $32, %cl # ascii sapce 32 into cl to draw to screen
        pushl %edx
        call mp1_poke
        popl %edx
 
    redraw_new_missile: # 3rd missile simply moving, redraw it in its new position
        movl VX(%ebx), %esi # x_missile => esi
        movl VY(%ebx), %edi # y_missile => edi
        addl %esi, X(%ebx) # update position
        addl %edi, Y(%ebx) # update position
        movl X(%ebx), %esi # x_missile => esi
        movl Y(%ebx), %edi # y_missile => edi  
        sarl $16, %esi # shift 16 bits to store text-mode video location in high 16 bits
        sarl $16, %edi # shift 16 bits to store text-mode video location in high 16 bits
        imull $2, %esi, %esi # column offset 2
        imull $160, %edi, %edi # row offset 160
        addl %esi, %edi # offset from the start of video memory
        movl %edi, %eax # move the offset into eax
        movb C(%ebx), %cl # move the character of the missile into cl
        pushl %edx
        call mp1_poke
        popl %edx
        jmp next_missile # go to next missile
 
    missile_exploded: # missile is exploding, call missile_exploded
        pushl %ebx
        call missile_explode 
        popl %ebx
        cmpl $0, %eax
        je decrement_exploded_field # return value of missile_explode = 0, will not call notify_user
        pushl %ebx
        call mp1_notify_user  # call notify_user when the return value of missile_explode is not 0
        popl %ebx
 
    decrement_exploded_field:
        subl $1, EXPLODED(%ebx) # subtract 1 from the exploded field
        cmpl $0, EXPLODED(%ebx)
        jg draw_explosion # exploded filed > 0, draw the explosion
        jmp erase_remove
 
    draw_explosion:
        movl X(%ebx), %esi # x_missile => esi
        movl Y(%ebx), %edi # y_missile => edi
        sarl $16, %esi # shift 16 bits to store text-mode video location in high 16 bits
        sarl $16, %edi # shift 16 bits to store text-mode video location in high 16 bits
        imull $2, %esi, %esi # column offset 2
        imull $160, %edi, %edi # row offset 160
        addl %esi, %edi # offset from the start of video memory
        movl %edi, %eax # move the offset into eax
        movb $EXPLOSION, %cl # move the explosion character to cl to draw explosion
        pushl %edx
        call mp1_poke
        popl %edx
        jmp next_missile
 
    erase_remove: # erase the the screen by drawing spaces and remove from linked list
        movl X(%ebx), %esi # x_missile => esi
        movl Y(%ebx), %edi # y_missile => edi
        sarl $16, %esi # shift 16 bits to store text-mode video location in high 16 bits
        sarl $16, %edi # shift 16 bits to store text-mode video location in high 16 bits
        imull $2, %esi, %esi # column offset 2
        imull $160, %edi, %edi # row offset 160
        addl %esi, %edi # offset from the start of video memory
        movl %edi, %eax # move the offset into eax
        movb $32, %cl # ascii sapce == 32 into cl to draw to screen
        pushl %edx
        call mp1_poke # call mp1_poke to erase
        popl %edx
 
        call mp1_missile_remove # call mp1_missile_remove to remove and free the missile from the linked list
        movl %eax, %ebx # store the returned pointer back into ebx
        jmp check_list
 
    next_missile:
        movl NEXT(%ebx), %ebx # loop to the next missile
        jmp check_list
 
    all_missiles_updated:
        popl %edi #restore callee-saved registers
        popl %esi
        popl %ebx
        leave
        ret
# ----------------- mp1_missile_remove -------------------
 
mp1_missile_remove: # Removing a missile from the list, implemented separately
    pushl %ebp
    movl %esp, %ebp
    pushl %ebx  #protect callee-saved registers
    pushl %esi
    pushl %edi
    movl mp1_missile_list, %edx
    cmpl %edx, %ebx # pointer at the head
    je remove_head
 
    previous_pointer: # loop through edx to find the pointer before ebx
        movl NEXT(%edx), %esi
        cmpl %esi, %ebx
        je remove_body
        movl %esi, %edx
        jmp previous_pointer # loop to the next pointer in edx to compare with ebx
 
    remove_body: # to remove the pointer that is not the head of the linked list
        movl NEXT(%ebx), %ecx
        movl %ecx, NEXT(%edx) # store the pointer after ebx to the position of ebx in edx
        pushl %edx
        pushl %ebx
        call mp1_free
        popl %ebx
        popl %edx
        movl NEXT(%edx), %eax # store the new pointer to eax to be returned by the function
        jmp return
 
    remove_head: # to remove the pointer that is the head of the linked list
        movl NEXT(%ebx), %ecx
        movl %ecx, mp1_missile_list # store the new head into mp1_missile_list
        pushl %ebx
        call mp1_free
        popl %ebx
        movl mp1_missile_list, %eax # store the new head to eax to be returned by the function
 
    return:
        popl %edi #restore callee-saved registers
        popl %esi
        popl %ebx
        leave
        ret
 
# ----------------- 2nd operation: redraw cities -------------------
 
update_cities:
    pushl %ebp
    movl %esp, %ebp
 
    pushl %ebx # protect callee-saved registers
    pushl %esi
    pushl %edi
 
    movl base_alive, %edx # city status => edx
 
    movl $3, %esi # city check counter => esi
    movl $18, %ecx # start location of the first city 18 => ecx
    imull $2, %ecx, %ecx # column offset 18 * 2 => ecx
    addl  $3840, %ecx # add the row offset 24*160 = 3840 => ecx
    movl %ecx, %eax # starting address for the first base now in eax
    check_city:
        movl $5, %edi # width counter of city 5 => edi
        cmpb $0, %dl # check the status of the city
        jge city_dead
 
    city_alive:
        movl $base_pic, %ebx # pic of the live base => ebx
        jmp draw_city
   
    city_dead:
        movl $dead_base_pic, %ebx # pic of the dead base => ebx
 
    draw_city: # draw the city on the screen
        movb NEXT(%ebx), %cl # move the pic into cl to draw
        pushl %edx
        call mp1_poke # draw the pic
        popl %edx
 
        addl $2, %eax # eax + row offset 1* 2 => eax
        addl $1, %ebx # ebx + 1 , new pic for base stored in edx
        subl $1, %edi # width counter -1
        cmpl $0, %edi # check if finsh drawing the base
        je next_city # finish drawing, loop to next city
        jmp draw_city # not finished, loop back to draw_city
 
    next_city:
        addl $32, %eax # eax + row offset 2 * 20 => eax
                       # starting address of the next base now in eax
        shrl $8, %edx  # right shift edx to find the status of the next base
        subl $1, %esi  # decrement base counter by 1
        cmpl $0, %esi  # check if finish drawing all bases
        je city_return # finshed updating all 3 base, return
        jmp check_city # loop back to update next base
 
    city_return:
        popl %edi #restore callee-saved registers
        popl %esi
        popl %ebx
        leave
        ret
 
# ----------------- 3rd operation: redraw crosshairs -------------------
update_crosshairs:
    pushl %ebp
    movl %esp, %ebp
 
    pushl %ebx # protect callee-saved registers
    pushl %esi
    pushl %edi
    xorl %eax, %eax
    xorl %ebx, %ebx
    imull $2, crosshairs_x, %eax
    imull $160, crosshairs_y, %ebx
    addl %ebx, %eax
    movb $43, %cl # ascii 43 for + to draw to screen
    pushl %edx
    call mp1_poke
    popl %edx
 
    xhair_return:
        popl %edi #restore callee-saved registers
        popl %esi
        popl %ebx
        leave
        ret
# ----------------- ioctl -------------------
 
mp1_ioctl_startgame:
    pushl %ebp
    movl %esp, %ebp
 
    pushl %ebx #protect callee-saved registers
    pushl %esi
    pushl %edi
 
    movl $0, mp1_missile_list
    movl $0xFFFFFFFF, base_alive
    movl $0, mp1_score
    movl $40, crosshairs_x
    movl $12, crosshairs_y
    
    popl %edi #restore callee-saved registers
    popl %esi
    popl %ebx
    leave
    ret
 
mp1_ioctl_addmissile:
    pushl %ebp
    movl %esp, %ebp
 
    pushl %ebx # protect callee-saved registers
    pushl %esi
    pushl %edi
 
    movl 8(%ebp), %ebx
 
    pushl $33
    call mp1_malloc # allocate 33 bits
    addl $4, %esp
 
    cmpl $0, %eax # check if mp1_malloc failed
    je failed_without_free_momory
 
    pushl $33
    pushl %ebx
    pushl %eax
    call mp1_copy_from_user
    cmpl $0, %eax # check if mp1_copy_from_user failed
    jne failed_with_free_memory
    jmp succeed
 
    failed_without_free_momory :
        movl $-1, %eax # return -1 when either failed
        jmp addmissile_return
 
    failed_with_free_memory:
        popl %eax
        popl %ebx
        addl $4, %esp
        pushl %eax
        call mp1_free # free memory allocated before return -1
        popl %eax
        movl $-1, %eax # return -1 when either failed
        jmp addmissile_return
 
    succeed:
        popl %eax
        popl %ebx
        addl $4, %esp
        movl mp1_missile_list, %edx
        movl %edx, NEXT(%eax)
        movl %eax, mp1_missile_list # add new missile into linked list
        movl $0, %eax  # return 0 when succeed
 
    addmissile_return:
        popl %edi #restore callee-saved registers
        popl %esi
        popl %ebx
        leave
        ret
 
mp1_ioctl_movexhairs:
    pushl %ebp
    movl %esp, %ebp
 
    pushl %ebx #protect callee-saved registers
    pushl %esi
    pushl %edi
    erase_old_xhair:
        imull $2, crosshairs_x, %esi # column offset 2
        imull $160, crosshairs_y, %edi # row offset 160
        addl %esi, %edi # offset from the start of video memory
        movl %edi, %eax # move the offset into eax
        movb $32, %cl # move the space character to cl to draw explosion
        pushl %edx
        call mp1_poke
        popl %edx
 
    update_xhair_location:
        movl 8(%ebp), %ebx # store the velocity into ebx
        movw %bx, %si
        sall $16, %esi
        sarl $16, %esi # sign extend esi
 
        sarl $16, %ebx # sign extend ebx
        addl %esi, crosshairs_x # update the x position
        addl %ebx, crosshairs_y # update the y position
 
    check_xhair:
        cmpl $0, crosshairs_x # check if xhair reach the x-least boundary
        jl x_low
        cmpl $79, crosshairs_x # check if xhair reach the x-most boundary
        jg x_high
        cmpl $0, crosshairs_y # check if xhair reach the y-least boundary
        jl y_low
        cmpl $24, crosshairs_y # check if xhair reach the y-most boundary
        jg y_high
        jmp draw_new_xhair
 
    x_low:
        movl $0, crosshairs_x
        jmp check_xhair
 
    x_high:
        movl $79, crosshairs_x
        jmp check_xhair
 
    y_low:
        movl $0, crosshairs_y
        jmp check_xhair
 
    y_high:
        movl $24, crosshairs_y
        jmp check_xhair
 
    draw_new_xhair:
        imull $2, crosshairs_x, %esi # column offset 2
        imull $160, crosshairs_y, %edi # row offset 160
        addl %esi, %edi # offset from the start of video memory
        movl %edi, %eax # move the offset into eax
        movb $43, %cl # move the space character to cl to draw explosion
        pushl %edx
        call mp1_poke
        popl %edx
 
    movexhair_return:
        popl %edi #restore callee-saved registers
        popl %esi
        popl %ebx
        leave
        ret
 
mp1_ioctl_getstatus:
    pushl %ebp
    movl %esp, %ebp
 
    pushl %ebx #protect callee-saved registers
    pushl %esi
    pushl %edi
 
    xorl %ebx, %ebx
    movl base_alive, %ebx # city status => ebx
    movl $3, %esi # city check counter => esi
    xorl %edx, %edx # set edi to 0 to store the status of the cities
 
    status_check_city:
        cmpb $0, %bl
        jge status_city_dead
   
    status_city_alive:
        addl $1, %edx # add 1 to esi if the city is alive
        jmp status_loop
 
    status_city_dead:
        addl $0, %edx
   
    status_loop:
        shll $1, %edx  # shift esi to store the next city's status
        sarl $8, %ebx  # shift ebx to find the status of the next base
        subl $1, %esi  # decrement base counter by 1
        cmpl $0, %esi  # check if finish drawing all bases
        je status_score_copy
        jmp status_check_city
 
    status_score_copy:
        shll $16, %edx # shift edi to save score
        movw mp1_score, %dx
        movl %edx, address
        pushl $4
        pushl $address
        pushl 8(%ebp)
        call mp1_copy_to_user
        addl $12, %esp
        cmpl $0, %eax
        jne status_failed
 
    status_succeed:
        movl $0, %eax
        jmp status_return
 
    status_failed:
        movl $-1, %eax # return -1 when either failed
        jmp status_return
 
    status_return:
        popl %edi #restore callee-saved registers
        popl %esi
        popl %ebx
        leave
        ret
 
mp1_ioctl_endgame:
    pushl %ebp
    movl %esp, %ebp
 
    pushl %ebx #protect callee-saved registers
    pushl %esi
    pushl %edi
 
    end_loop:
        movl mp1_missile_list, %ebx
        cmpl $0, %ebx
        je end_return
        movl NEXT(%ebx), %edi
        movl %edi, mp1_missile_list
        pushl %ebx
        call mp1_free
        addl $4, %esp
        jmp end_loop
 
    end_return:
        popl %edi #restore callee-saved registers
        popl %esi
        popl %ebx
        leave
        ret
        