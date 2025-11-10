; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

#include "p16f887.inc"

; CONFIG1
; __config 0x23E1
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
; __config 0x3FFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF


;---------------------------------Variables-----------------------------------
Contador1   EQU 0x20
Contador2   EQU 0x21
Contador3   EQU 0x22
VALOR_INGRESADO_RPM EQU 0X23
W_TEMP EQU 0X70
STATUS_TEMP EQU 0X71

;---------------------------------Código--------------------------------------
    ORG 0x00
    GOTO INICIO
    
    ORG 0X04
    GOTO ISR

INICIO
    
    
   ;----------------------------------------------------------------------------------------------------------------------
   ; ESCRIBO UN  BLOQUE DE CODIGO PARA ASEGURARME DE QUE NO PODAMOS PEDIR AL PWM UN ANCHO DEL PULSO MAYOR AL VALOR MAXIMO
   ;-----------------------------------------------------------------------------------------------------------------------
   
    ;MOVF VALOR_INGRESADO_RPM, W    ; W = valor ingresado
    ;SUBLW D'255'                   ; Calcula 255 - W
    ;BTFSS STATUS, C                ; Si C=1, el valor <=255 
    ;CLRF VALOR_INGRESADO_RPM		; SI EL VALOR INGRESADO ES MAYOR QUE EL MAXIMO, LO PONGO EN CERO
    
   
    
    ;--- Configuración general ---
    clrf    ANSEL
    clrf    ANSELH             ; todo digital

    BANKSEL TRISC
    bcf     TRISC, 2           ; PIN RC2 (CCP1) COMO salida

    ;--- Configuración del PWM ---
    BANKSEL CCP1CON
    movlw   b'00001100'        ; ACTIVO EL MODO PWM Y PONGO LOS 2 BITS LSB EN BAJO PORQUE NO LOS USAMOS 
    movwf   CCP1CON

    MOVLW   D'66'              ; PARA UNA FRECUENCIA CONSTANTE DE 12KHZ TENGO UN PR2 DE 83
    BANKSEL PR2
    movwf   PR2

    BANKSEL T2CON
    MOVLW   B'00000100'        ; Prescaler EN 1 Y TMR2 ENCENDIDO (ARRANCA EL PWM)
    MOVWF   T2CON
    CALL    Delay1s            ; ESPERO 1 SEGUNDO PARA ESTABILIZAR EL MODULO CCP
    
    
    
    ;--- CONFIGURACION INTERRUPCION PWM ---
    BANKSEL PIR1
    BCF PIR1, 1			; BAJO LA BANDERA DE DESBORDE TMR2
    
    BANKSEL PIE1
    BSF PIE1, 1			; ACTIVO INTERRUPCION POR MATCH DE TMR2 A PR2
    
    MOVLW B'11110000'		; GIE=1, PEIE= 1, T0IE=1, INTE=1, RBIE=1, T0IF=0, INTF=0, RBIF=0
    MOVWF INTCON 
    
    MOVLW   D'30'
    MOVWF   VALOR_INGRESADO_RPM
    ;---------------------------------------------------------------------------------------------
    ;Necesitás habilitar las interrupciones periféricas (bit PEIE en INTCON)
    ;porque el Timer2 es un periférico, no un temporizador principal del núcle
    ;---------------------------------------------------------------------------------------------

 
    
LOOP 
    GOTO LOOP			; ESPERAMOS INTERRUPCIONES
    
    
    
  
ISR
    MOVWF   W_TEMP			; GUARDO CONTEXTO 
    SWAPF   STATUS,W
    MOVWF   STATUS_TEMP
    
    BTFSC    PIR1, 1			; PREGUNTO POR LA BANDERA DE DESBORDE TMR2
    GOTO    TMR2_ISR
    
     
    
	
TMR2_ISR
    MOVF VALOR_INGRESADO_RPM,0	  ; EL VALOR DE RPM QUE INGRESE SE PEGA EN W
    BANKSEL CCPR1L
    MOVWF   CCPR1L             ; W -> CCPR1L (8 bits MSB del duty)
    BCF     CCP1CON,5          ; PONGO LOS 2 BITS LSB EN BAJO PORQUE NO LOS USAMOS 
    BCF     CCP1CON,4
    BCF     PIR1, 1			; BAJO LA BANDERA DE DESBORDE TMR2
    
    GOTO FIN_ISR
    
    


Delay1s				; Delay de 1 segundo 
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

    
FIN_ISR
    SWAPF	STATUS_TEMP, W		; RECUPERO CONTEXTO 
    MOVWF	STATUS
    SWAPF	W_TEMP, F
    SWAPF	W_TEMP, W			 
    RETFIE

	
	
    END
