//******************************************************************************************************************
;Universidad del Valle de Guatemala 
;IE2023: Programación de Microcontroladores 
; Autor: Héctor Martínez 
; Hardware: ATMEGA328p
;PROYECTO RELOJ
//******************************************************************************************************************
//ENCABEZADO
//******************************************************************************************************************
.INCLUDE "M328PDEF.INC"
.DEF MODO = R20
.DEF ESTADO = R21
.DEF CONTADOR = R22


.CSEG
.ORG 0x0000
	JMP MAIN:				;Vector Reset
.ORG 0x0020
	JMP ISR_TIMER0_OVF		;Vector ISR de timer0
MAIN: 
//******************************************************************************************************************
//STACK POINTER
//******************************************************************************************************************	
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17	
//******************************************************************************************************************

//******************************************************************************************************************
//Configuración 
//******************************************************************************************************************
Setup:
	LDI R16, 0b1000_0000
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16								;Habilitando presacaler

	LDI R16, 0b0000_0001						
	STS CLKPR, R16								;Frecuencia 8MHz

	SBI PORTC, PC0								;Habilitando PULL-UP en PC0
	CBI DDRC, PC0								;Habilitando PC0 como entrada

	SBI PORTC, PC1	
	CBI DDRC, PC1								

	SBI PORTC, PC2	
	CBI DDRC, PC2

	SBI PORTC, PC3	
	CBI DDRC, PC3

	SBI PORTC, PC4	
	CBI DDRC, PC4								;MODO

	LDI R16, 0b01111111							;Establecer PD0 a PD6 como salidas del display
	OUT DDRD, R16

	LDI R16, 0b00011111							;Establecer PB0 a PB4 como salidas
;alarma 

MAIN:
;*****************************************************************
;STACK POINTER 
;*****************************************************************
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17

;*****************************************************************
;CONFIGURACIÓN
;*****************************************************************
SETUP:


	LDI R16, 0b1000_0000
	LDI R16, (1<<CLKPCE)					;Corrimiento a CLKPCE
	STS CLKPR, R16

	LDI R16, 0b0000_0001					
	STS CLKPR, R16							;Frecuencia del sistema de 8MHz

	LDI R16, 0b11111111
	OUT DDRD, R16							;Configurar pin PD0 a PD6 como salida

	LDI R16, 0b00001111
	OUT DDRB, R16							;Configurar PB1 y PB2 como entrada y PB3 y PB4 como salida}
	LDI R16, 0b00001111
	OUT PORTB, R16							;Configurar PULLUP de pin PB1 Y PB2

	LDI R16, 0b00111111
	OUT DDRC, R16
	LDI R18, 0

	LDI R16, (1<<PCIE0)
	STS PCICR, R16							;Habilitando PCINT 0-7 

	LDI R16, (1<<PCINT1)|(1<<PCINT2)
	STS PCMSK0, R16							;Registro de la máscara
	SBI PINB, PB4							;Enceder display 2
	SEI										;Habilitar interrupciones globales
	LDI R19, 0								;Displays
	LDI R17, 0
	LDI R28, 0
	LDI R25, 0 

	TABLA: .DB 0x7D,0x48,0x3E,0x6E,0x4B,0x67,0x77,0x4C,0x7F,0x4F
	LDI R22, 0								;Contador de unidades 
	LDI R21, 0								;Contador de decenas
	CALL INITTIMER0


LOOP: 
	CPI R22, 10
	BREQ RESETT
	CPI R23, 50								
	BREQ UNIDADES

		CALL RETARDO 
		SBI PINB, PB3
		SBI PINB, PB4

		LDI ZH, HIGH(TABLA<<1)			;Da el byte menos significativo
		LDI ZL, LOW(TABLA<<1)			;Va a dirección de TABLA
		ADD ZL, R21
		LPM R25, Z
		OUT PORTD, R25


		CALL RETARDO
		SBI PINB, PB3
		SBI PINB, PB4
		
		LDI ZH, HIGH(TABLA<<1)			;Da el byte menos significativo
		LDI ZL, LOW(TABLA<<1)			;Va a dirección de TABLA
		ADD ZL, R22
		OUT PORTD, R25
		CALL RETARDO 

		CPI R21, 6
		BREQ RESDE
	JMP LOOP								;Regresa al LOOP

	RETARDO:
	LDI R19, 255							;Cargar con una valor a R16
	delay:
		DEC R19								;Decrementa R16
		BRNE delay							;Si R16 no es igual a 0, tira al delay
	LDI R19, 255							;Carga con un valor a R16
	delay1:
		DEC R19								;Decrementa R16
		BRNE delay1							;Si R16 no es igual a 0, tira al delay
	LDI R19, 255							;Carga con un valor a R16
	delay2:
		DEC R19								;Decrementa R16
		BRNE delay2							;Si R16 no es igual a 0, tira al delay
	LDI R19, 255							;Carga con un valor a R16
	delay3:
		DEC R19								;Decrementa R16
		BRNE delay3							;Si R16 no es igual a 0, tira al delay

	RET

	RESETT:									;Reset para el contadoe de unidades
		LDI R22, 0
		INC R21								;Suma de contador de decenas
		JMP LOOP 

	UNIDADES:								;Contador de Unidades
		INC R22
		LDI R23, 0
		JMP LOOP

	RESDE:
		CALL RETARDO 
		LDI R21, 0
		LDI R22, 0
		JMP LOOP


;*****************************************************************
;Inicio del timer0
INITTIMER0:									;Arrancar timer0
	LDI R26, 0
	OUT TCCR0A, R26							;Trabajar de forma normal con el temporizador
	
	LDI R26, (1<<CS02)|(1<<CS00)
	OUT TCCR0B, R26							;Configurar el temporizador con prescaler de 1024	 

	LDI R26, 100
	OUT TCNT0, R26							;Iniciar timer en 158 para conteo 

	LDI R26, (1<<TOIE0)
	STS TIMSK0, R26							;Activar interrupción del timer0 de máscara por overflow

	RET

;*****************************************************************
;Subrutina de pulsadores

ISR_PCINT0:
	PUSH R16								;Se guarda en pila de registro R16
	in R16, SREG
	PUSH R16

	IN R20, PINB							;Leer puerto B
	SBRC R20, PB1							;Salta si el bit del registro  es 1

	JMP CPB2								;Verifica si esta presionado el pin PB2

	DEC R18									;Decrementa R18
	JMP EXIT

CPB2: 
	SBRC R20, PB2							;verifica si PB2 esta a 1
	JMP EXIT

	INC R18									;Incrementa R18
	JMP EXIT

EXIT: 
	CPI R18, -1
	BREQ res1
	CPI R18, R16
	BREQ res2

	OUT PORTC, R18
	SBI PCIFR, PCIF0						;Apagar la bandera de ISR PCINT0

	POP R16									;Obtener el valor de SREG
	OUT SREG, R16							;Restaurar los valores de SREG 
	POP R16
	RETI									;Retorna de la ISR

res1:										;reseteo del valor bajo
	LDI R18, 0
	OUT PORTC, R18
	JMP EXIT

res2:										;reseteo del valor alto
	LDI R18, 15
	OUT PORTC, R18
	JMP EXIT
	
;*****************************************************************
;Subrutina del Timer0

ISR_TIMER0_OVF:
	PUSH R16								;Se guarda R16 en la pila
	IN R16, SREG					
	PUSH R16

	LDI R16, 100							;cargar el valor de desbordamiento 
	OUT TCNT0, R16							;cargar el valor inicial del contador 
	SBI TIFR0, TOV0							;borra la bandera de TOV0
	INC R23									;incrementar el contador de 20ms 

	POP R16									;Obtener el valor del SREG
	OUT SREG, R16							;restaurar antiguas valores del SREG
	POP R16									;Obtener el valor de R16

	RETI									;retornar al LOOP

//ALARMA

//******************************************************************************************************************
//Subrutina para inicializar TIMER0
//******************************************************************************************************************
INITIMER0: 
	LDI R16, (1<<CS02)|(1<<Cs00)		;Configurar el prescaler a 1024
	OUT TCCR0B, R16

	LDI R16, 100						;Cargar el valor de desbordamiento 
	OUT TCNT0, R16						;Cargar el valor inicial del contador

LOOP:
	SBRS ESTADO, 0
	JMP EstadoX0
	JMP EstadoX1

EstadoX0:
	SBRS ESTADO, 1
	JMP Estado00
	JMP Estado10


EstadoX1:
	SBRS ESTADO, 1
	JMP Estado01
	JMP Estado11

Estado00:
	



	CPI R23, 50  //Verificar cuantas pasadas a dado el TIMER0
	BRNE LOOP
	CLR R23
	SBI PIND, PD4	
	

	RJMP LOOP  //Bucle principal infinito


INITTIMER0:
	LDI R26, 0
	OUT TCCR0A, R26 //trabajar de forma normal con el temporizador

	LDI R26, (1<<CS02)|(1<<CS00)
	OUT TCCR0B, R26  //Configurar el temporizador con prescaler de 1024

	LDI R26, 237
	OUT TCNT0, R26 //Iniciar timer en 158 para conteo

	LDI R26, (1 << TOIE0)
	STS TIMSK0, R26 //Activar interrupción del TIMER0 de mascara por overflow
	
	RET
//******************************************************************************************************************
//Subrutina para inicializar TIMER0
//******************************************************************************************************************

ISR_TIMER0_OVF:
	PUSH R16   //Se guarda R16 En la pila 
	IN R16, SREG  
	PUSH R16      //Se guarda SREG actual en R16

	LDI R16, 237  //Cagar el valor de desbordamiento
	OUT TCNT0, R16  //Cargar el valor inicial del contador
	SBI TIFR0, TOV0   //Borrar la bandera de TOV0
	INC R23    //Incrementar el contador de 20ms

	POP R16    //Obtener el valor del SREG
	OUT SREG, R16   //Restaurar antiguos valores del SREG
	POP R16    //Obtener el valor de R16
	
	RETI