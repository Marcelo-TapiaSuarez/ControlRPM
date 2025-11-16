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


INICIO
; ------------------------------- Configuración UART ------------------------------------------------- ;
	BANKSEL	TXSTA

	MOVLW	B'00100100'
	MOVWF	TXSTA		;Configuro la Transmisión

	MOVLW	D'103'
	MOVWF	SPBRG		; Cargo SPBRG para Baud Rate
	CLRF	SPBRGH		; Limpo SPBRGH

	CLRF	TRISD

	BANKSEL	RCSTA

	MOVLW	B'10000000'
	MOVWF	RCSTA		;Configuro la Recepción

	CLRF	RPM
	CLRF	ADC_H
	CLRF	ADC_L
	MOVLW	0X21
	MOVWF	START_SYNC_TX


	BANKSEL	BAUDCTL

	MOVLW	B'01001000'
	MOVWF	BAUDCTL		;Configuro Baud Rate

; ---------------------------------- Configuración del PWM --------------------------------------------- ;
	BANKSEL TRISC
	BCF	TRISC, 2    ; RC2 como salida
	
	BANKSEL CCP1CON
	MOVLW   B'00001100'        ; ACTIVO EL MODO PWM Y PONGO LOS 2 BITS LSB EN BAJO PORQUE NO LOS USAMOS 
	MOVWF   CCP1CON

	MOVLW   D'63'              ; PARA UNA FRECUENCIA CONSTANTE DE 12KHZ TENGO UN PR2 DE 83
	BANKSEL PR2
	MOVWF   PR2

	BANKSEL T2CON
	MOVLW   B'00000100'        ; Prescaler EN 1 Y TMR2 ENCENDIDO (ARRANCA EL PWM)
	MOVWF   T2CON
	CALL    Delay1s            ; ESPERO 1 SEGUNDO PARA ESTABILIZAR EL MODULO CCP
	
	BANKSEL	CCPR1L
	MOVLW	D'0'
	MOVWF	VALOR_RPM
	BSF	FLAG, 0
    
; ------------------------------------- Configuración ADC ----------------------------------------------- ;
    ;------ CONFIGURO EL PUERTO -------- ;
	BANKSEL TRISA 			;PORTA COMO ENTRADA (ADEMAS DESHABILITO EL BUFFER DE SALIDA)
	MOVLW	B'00000001'
	MOVWF	TRISA 
	
	CLRF	TRISD			;PORTD COMO SALIDAS DIGITALES
	
	BANKSEL	PORTA			; BANCO 0
	BSF	START, 0
	CLRF	NAFTA
	CLRF	FLAG_ADC

	BANKSEL ANSEL			;PORTA COMO ENTRADA ANALÓGICA 
	MOVLW	B'00000001'
	MOVWF	ANSEL

	BANKSEL	PORTA
	CLRF	PORTB 			; LIMPIO LOS PUERTOS
	CLRF	PORTD
		
    ; ------ CONFIGURO EL BUFFER DE SALIDA ---------- ;
	BANKSEL ADCON1			 ; CONFIGURO TENSIONES DE REFERENCIA Y FORMATO DE SALIDA 
	MOVLW	B'10000000' 		 ;Vdd and Vss as Vref Y JUSTIFICACION POR IZQUIERDA
	MOVWF	ADCON1		 	
	
	BANKSEL ADCON0  
	MOVLW	B'01000001'		; ADC ENABLED, GO=0, SELECCIONO CANAL AN4, SELECCIONO FOSC/2
	MOVWF	ADCON0	
	
	CALL	DELAY_20US
	BSF	ADCON0, 1			; INICIO LA CONVERSIÓN
	BSF	FLAG_ADC, 1			; Haciendo conversion, ADC ocupado
	
; ---------------------------------------- Configuración RB ---------------------------------------------------- ;
	BANKSEL	ANSELH
	CLRF	ANSELH
	
    ; -------- HABILITO PULL UP ------------- ;
	BANKSEL	OPTION_REG
	MOVLW	B'00000000'		
	MOVWF	OPTION_REG
	
    ; ------ CONFIG PUERTOS PARA INTERRUPCION -------- ;
	MOVLW   b'00000011' 
	MOVWF   TRISB ; RB1-RB0 como SALIDA, el resto como ENTRADA
	MOVLW   b'00000011'
	MOVWF   WPUB  ; Habilitamos solo las resistencias de pull up DE RB1-RB0
	MOVLW   B'00000010'
	MOVWF   IOCB

    
; --------------------------------- Configuración Interrupciones ----------------------------------------------- ;
    BANKSEL	INTCON
    
    BCF		INTCON, 0	; Deshabilito bandera RBIF
    BCF		INTCON, 1	; Deshabilito bandera INTE
    
    BANKSEL	PIR1
    CLRF	PIR1		; Deshabilito banderas de PIR1
    
    BANKSEL	INTCON
    
    MOVLW	B'11011000'
    MOVWF	INTCON		; Habilito Interrupciones GIE, PEIE, INTE, RBIE
    
    BANKSEL	PIE1
    MOVLW	B'01100010'
    MOVWF	PIE1		; Habilito Interrupción ADIE, RCIE, TMR2IE



LOOP:
    BANKSEL PORTA
    BTFSC   FLAG, 7
    CALL    ANTIRREBOTE

    BANKSEL PIR1
    BTFSC   PIR1, TXIF
    CALL    TANSMISION
    
    BANKSEL PORTD
    BTFSC   FLAG_ADC, 0		;Termino la conversion?
    BCF	    FLAG_ADC, 1		;Termino, ADC ready
    CALL    DELAY_20US			; ESPERAMOS UN TIEMPO DE CARGA
    BANKSEL ADCON0
    BSF	    ADCON0, 1			; INICIO LA CONVERSIÓN
    BSF	    FLAG_ADC, 1		;ADC ocupado

    GOTO LOOP



ANTIRREBOTE
    CALL    DELAY_20ms
    BCF	    FLAG, 7
    BCF	    INTCON, 1
    BSF	    INTCON, 4
    
    RETURN



TANSMISION
    ; ------------------ Algorítmo Básico para el envío de tres datos (3bytes) -------------------------- ;
    BANKSEL TXREG
    
    MOVF    START_SYNC_TX, W
    MOVWF   TXREG		    ; Cargo TXREG con un caracter de inicio
    CALL    BUFF_READY		    ; Buffer de envío libre?
    MOVF    ADC_H, W
    MOVWF   TXREG		    ; Cargo TXREG con el valor de ADRESL
    CALL    BUFF_READY		    ; Buffer de envío libre?
    MOVF    ADC_L, W		    
    MOVWF   TXREG		    ; Cargo TXREG con el valor de ADRESH
    
    CALL    Delay1s		    ; Delay de 1 segundo entre 3 datos
; --------------------------------------------------------------------------------------------------- ;
    RETURN
    

BUFF_READY
    BTFSS   PIR1, TXIF
    GOTO    BUFF_READY
    
    RETURN





ISR:
    MOVWF	W_TEMP			; GUARDO CONTEXTO 
    SWAPF	STATUS,W
    MOVWF	STATUS_TEMP
    
    ; -------------------------- ISR -------------------------------- ;
    
    BTFSC	INTCON, 1
    GOTO	ISR_INTE
    
    BTFSC	INTCON, 0
    GOTO	ISR_RBIE
    
    BTFSC	PIR1, RCIF
    GOTO	ISR_RX
    
    BTFSC	PIR1, TMR2IF
    GOTO	ISR_TMR2
    
    BTFSC	PIR1, ADIF
    GOTO	ISR_ADC
    
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

    BCF	    FLAG,0
    BSF	    RCSTA,4
    MOVLW   D'25'	    ; Arranca el motor con 10% de velocidad 
    MOVWF   VALOR_RPM
    GOTO    FIN_ISR

OFF
    ; -------- Rama OFF (START=0) --------
    BSF     PORTD,0       ; RD0 = 1  (Stop ON)
    BCF     PORTD,2       ; RD2 = 0  (Start OFF)

    BSF	    FLAG,0
    MOVLW   D'0'
    MOVWF   VALOR_RPM
    BCF	    RCSTA,4

    GOTO    FIN_ISR




ISR_RBIE:
    BCF	    INTCON, 0    ; Limpiar flag de interrupción externa
    MOVLW   0x02
    XORWF   NAFTA, F      ; Cambia entre 0 y 1
    MOVF    NAFTA,W
    MOVWF   PORTD
    
    BTFSC   NAFTA,0
    GOTO    RESERVA
   
    
    GOTO    FIN_ISR    
    
RESERVA
    
    MOVLW   D'77'
    MOVWF   VALOR_RPM
    GOTO    FIN_ISR




ISR_RX:
    BANKSEL RCREG
    
    MOVF    RCREG, W		; Leo RCREG
    MOVWF   START_SYNC_RX
    SUBLW   D'204'
    BTFSS   STATUS, Z		; Verifico si coincide con el caracter de Inicio 0xC9
    GOTO    FIN_ISR		; Si no coincide, sale de la ISR
    
    GOTO    CARGA_PWM		; Coincide, entonces, carga PWM
    
    GOTO    FIN_ISR
    

CARGA_PWM
    BANKSEL RCREG
    
    MOVWF   RPM
    MOVF    RPM, W
    
    BANKSEL PORTA
    MOVWF   VALOR_RPM
    
    GOTO    FIN_ISR



ISR_TMR2:
    BANKSEL CCPR1L
    BTFSS   FLAG, 0		  ; No divide por 4 si está apagado
    GOTO    DIVIDIR
    
    MOVF    VALOR_RPM, W	  ; EL VALOR DE RPM QUE INGRESE SE PEGA EN W
    SUBLW   D'255'		  ; Invierte el valor ingresado para invertir la logica
    MOVWF   RPM_TEMP
     
    MOVWF   CCPR1L             ; W -> CCPR1L (8 bits MSB del duty)
    BCF     CCP1CON,5          ; PONGO LOS 2 BITS LSB EN BAJO PORQUE NO LOS USAMOS 
    BCF     CCP1CON,4
    BCF     PIR1, 1			; BAJO LA BANDERA DE DESBORDE TMR2
    
    GOTO    FIN_ISR


DIVIDIR
    MOVF    VALOR_RPM, W	  ; EL VALOR DE RPM QUE INGRESE SE PEGA EN W
    SUBLW   D'255'		  ; Invierte el valor ingresado para invertir la logica
    MOVWF   RPM_TEMP
    BCF	    STATUS, C
    RRF	    RPM_TEMP, F
    RRF	    RPM_TEMP, F
    MOVF    RPM_TEMP, W
    
    MOVWF   CCPR1L             ; W -> CCPR1L (8 bits MSB del duty)
    BCF     CCP1CON,5          ; PONGO LOS 2 BITS LSB EN BAJO PORQUE NO LOS USAMOS 
    BCF     CCP1CON,4
    BCF     PIR1, 1			; BAJO LA BANDERA DE DESBORDE TMR2
    
    GOTO    FIN_ISR

ISR_ADC:
    BCF	    PIR1, 6				; BAJ0 BANDERA DE FIN DE CONVERSIÓN ADC
    BCF	    ADCON0, 1

    BANKSEL ADRESH	    ; BANCO 0
    MOVF    ADRESH, W
    MOVWF   AH
    MOVWF   ADC_H
    BANKSEL ADRESL	    ; BANCO 1
    MOVF    ADRESL, W
    BANKSEL PORTA	    ; BANCO 0
    MOVWF   AL
    MOVWF   ADC_L
    GOTO    D_DONE


D_DONE
    BCF	    FLAG_ADC, 1		;ADC desocupado
    BSF	    FLAG_ADC, 0		;Dato Listo
    GOTO    FIN_ISR











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