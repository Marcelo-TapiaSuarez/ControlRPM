; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

#include "p16f887.inc"

; CONFIG1
; __config 0x23E1
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
; __config 0x3FFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF


DATO	    EQU 0X20
W_TEMP	    EQU 0X70
STATUS_TEMP EQU 0X71


    ORG	    0X00
    GOTO    INICIO

    ORG	    0X04
    GOTO    ISR
 


INICIO:
    ; Configuración UART
    BANKSEL	TXSTA

    MOVLW	B'00100100'
    MOVWF	TXSTA		;Configuro la Transmisión
    
    MOVLW	D'103'
    MOVWF	SPBRG		; Cargo SPBRG para Baud Rate
    CLRF	SPBRGH		; Limpo SPBRGH
    
    CLRF	TRISD
    
    BANKSEL	RCSTA

    MOVLW	B'10010000'
    MOVWF	RCSTA		;Configuro la Recepción
    
    CLRF	PORTD

    BANKSEL	BAUDCTL

    MOVLW	B'01001000'
    MOVWF	BAUDCTL		;Configuro Baud Rate

    BANKSEL	INTCON

    MOVLW	B'11000000'
    MOVWF	INTCON		; Habilito Interrupción PEIE
    
    
    BANKSEL	PIR1
    CLRF	PIR1		; Deshabilito banderas de PIR1
    
    BANKSEL	PIE1
    MOVLW	B'00110000'
    MOVWF	PIE1		; Habilito Interrupción TXIE y RCIE del PIE1
    
    ;BANKSEL TXREG
    ;MOVLW   0x41
    ;MOVWF   TXREG


LOOP:


    GOTO    LOOP




ISR:
    ; Guardo Contexto
    MOVWF   W_TEMP			
    SWAPF   STATUS,W
    MOVWF   STATUS_TEMP

    ; ------------- ISR --------------- ;

    BTFSC   PIR1, TXIF	    ; TXREG vacio? -> TXIF = 1
    ;GOTO    ISR_TX
    
    BTFSC   PIR1, RCIF	    ; RCREG lleno? -> RXIF = 1
    GOTO    ISR_RX
    
    GOTO    FIN_ISR


ISR_TX:
    BANKSEL TXREG
    MOVLW   0X41
    MOVWF   TXREG
    
    
    GOTO    FIN_ISR


ISR_RX:
    BANKSEL RCREG
    MOVF    RCREG, W
    MOVWF   DATO
    
    BSF	    PORTD, 0
    GOTO    FIN_ISR
    
    
FIN_ISR:
    SWAPF   STATUS_TEMP, W		; RECUPERO CONTEXTO 
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W

    RETFIE
    
    
    END