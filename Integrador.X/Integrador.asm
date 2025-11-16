; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

#include "p16f887.inc"

; CONFIG1
; __config 0x23E1
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
; __config 0x3FFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF



; ---------- Variables para delay ---------------- ;

Contador1	EQU 0x20
Contador2	EQU 0x21
Contador3	EQU 0x22
; ------------------------------------------------ ;

; ---------- Variables PWM ----------------------- ;
VALOR_RPM	EQU 0X24
RPM_TEMP	EQU 0X25
; ------------------------------------------------ ;

; ----------- Variablws UART --------------------- ;
RPM		EQU 0X26
FLAG		EQU 0X27

ADC_L		EQU 0X28
ADC_H		EQU 0X29

START_SYNC_TX   EQU 0X2A
START_SYNC_RX	EQU 0X2B
; ------------------------------------------------ ;

; ------------ Variables ADC --------------------- ;
NAFTA		EQU 0X30	; Tanque de combustible (reserva = 0, lleno = 1)
FLAG_ADC	EQU 0X31	
START		EQU 0X32	; Boton de on/off (off = 0, on = 1)
AL		EQU 0X33	; Copia de ADRESL
AH		EQU 0X34	; Copia de ADRESH
CONT		EQU 0X35
; ------------------------------------------------ ;


; ------------ Variables generales --------------- ;
W_TEMP		EQU 0X70
STATUS_TEMP	EQU 0X71
; ------------------------------------------------ ;


	ORG	0X00
	GOTO	INICIO
	ORG	0X04
	GOTO	ISR


INICIO:
	BANKSEL TRISD
	CLRF	TRISD
	
	BANKSEL PORTD
	CLRF	PORTD
	
	BANKSEL	START
	CLRF	START
	BSF	START,0
; ---------------------------------------- Configuración RB ---------------------------------------------------- ;
	BANKSEL	ANSELH
	CLRF	ANSELH
	
    ; -------- HABILITO PULL UP ------------- ;
	BANKSEL	WPUB		; Banco 1
	MOVLW	B'00000000'		
	MOVWF	OPTION_REG
	
    ; ------ CONFIG PUERTOS PARA INTERRUPCION -------- ;
	MOVLW   B'00000011' 
	MOVWF   TRISB ; RB1-RB0 como ENTRADA, el resto como SALIDA
	MOVLW   B'00000011'
	MOVWF   WPUB  ; Habilitamos solo las resistencias de pull up DE RB1-RB0
	MOVLW   B'00000010'
	MOVWF   IOCB

    
; --------------------------------- Configuración Interrupciones ----------------------------------------------- ;
    BANKSEL	INTCON
    
    CLRF	INTCON
    
    BANKSEL	PIR1
    CLRF	PIR1		; Deshabilito banderas de PIR1
    
    BANKSEL	INTCON
    
    MOVLW	B'10010000'
    MOVWF	INTCON		; Habilito Interrupciones GIE, PEIE, INTE, RBIE
    
    BANKSEL	PIE1
    MOVLW	B'01100010'
    MOVWF	PIE1		; Habilito Interrupción ADIE, RCIE, TMR2IE

    GOTO	LOOP

LOOP:
    BANKSEL PORTA
    BTFSC   FLAG, 7
    CALL    ANTIRREBOTE

	
    GOTO LOOP

ANTIRREBOTE
    CALL    DELAY_20ms
    BCF	    FLAG, 7
    BCF	    INTCON, 1
    BSF	    INTCON, 4
    
    RETURN



ISR:
    MOVWF	W_TEMP			; GUARDO CONTEXTO 
    SWAPF	STATUS,W
    MOVWF	STATUS_TEMP
    
    ; -------------------------- ISR -------------------------------- ;
    BANKSEL	INTCON
    
    BTFSC	INTCON, 1
    GOTO	ISR_INTE
    
    ;BTFSC	INTCON, 0
 ;   GOTO	ISR_RBIE
    
    
    ; --------------------------------------------------------------- ;
    
    GOTO	FIN_ISR




ISR_INTE:
    BANKSEL INTCON
    BCF	    INTCON, 1    ; Limpiar flag INTF
    BCF	    INTCON, 4    ; Deshabilito INTE (antirrebote por hardware)

    ; ---- Toggle de START ----
    BANKSEL START
    MOVLW   0x01
    XORWF   START, F      ; Cambia bit0

    ; Aviso al main para que haga el delay
    BANKSEL FLAG
    BSF     FLAG, 7

    ; ---- Actualizar LEDs según START ----
    BANKSEL PORTD
    BTFSS   START,0       ; ¿START=1?
    GOTO    OFF           ; NO -> rama OFF

    ; -------- Rama ON (START=1) --------
    BCF     PORTD,0       ; RD0 = 0  (Stop OFF)
    BSF     PORTD,2       ; RD2 = 1  (Start ON)

    ; (lo demás que quieras hacer cuando está ON)
    BCF   FLAG,0
    BSF   RCSTA,4
    MOVLW D'0'
    MOVWF VALOR_RPM
    GOTO    FIN_ISR

OFF
    ; -------- Rama OFF (START=0) --------
    BSF     PORTD,0       ; RD0 = 1  (Stop ON)
    BCF     PORTD,2       ; RD2 = 0  (Start OFF)

    ; (lo demás cuando está OFF)
    BSF   FLAG,0
    MOVLW D'255'
    MOVWF VALOR_RPM
    BCF   RCSTA,4

    GOTO    FIN_ISR




;ISR_RBIE:
;    BCF	    INTCON, 0    ; Limpiar flag de interrupción externa
;   MOVLW   0x02
;    XORWF   NAFTA, F      ; Cambia entre 0 y 1
;    MOVF    NAFTA,W
;    MOVWF   PORTD
;    
;    BTFSC   NAFTA,0
;    GOTO    RESERVA
   
    
;    GOTO    FIN_ISR    
    
;RESERVA
    
;    MOVLW   D'77'
;    MOVWF   VALOR_RPM
;    GOTO    FIN_ISR



FIN_ISR:
	
	SWAPF	STATUS_TEMP, W		; RECUPERO CONTEXTO 
	MOVWF	STATUS
	SWAPF	W_TEMP, F
	SWAPF	W_TEMP, W
				 
	RETFIE


; ------------------ Delay de 1 segundo --------------------- ;
Delay1s	
    MOVLW   D'10'
    MOVWF   Contador1
Loop1s
    CALL    Delay100ms
    DECFSZ  Contador1,F
    GOTO    Loop1s
    RETURN

Delay100ms
    MOVLW   D'100'
    MOVWF   Contador2
Loop100ms
    CALL    Delay1ms
    DECFSZ  Contador2,F
    GOTO    Loop100ms
    RETURN

Delay1ms
    MOVLW   D'250'
    MOVWF   Contador3
Loop1ms
    NOP
    NOP
    DECFSZ  Contador3,F
    GOTO    Loop1ms
    RETURN


; ------------------ Delay de 20us --------------------- ;    
DELAY_20US
    MOVLW   D'19'
    MOVWF   CONT
BUCLE
    DECFSZ  CONT,F
    GOTO    BUCLE
    RETURN



; ------------------ Delay de 20ms --------------------- ;
DELAY_20ms
    MOVLW   D'200'        ; Loop externo (200 veces)
    MOVWF   Contador2

Delay20_Loop2
    MOVLW   D'50'         ; Loop interno (50 veces)
    MOVWF   Contador1

Delay20_Loop1
    NOP                   ; 1 ciclo
    NOP                   ; 1 ciclo
    DECFSZ  Contador1, F      ; 1 (o 2)
    GOTO    Delay20_Loop1 ; 2 ciclos

    DECFSZ  Contador2, F
    GOTO    Delay20_Loop2

    RETURN
    
    
    END