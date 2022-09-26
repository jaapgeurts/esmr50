module iec62056;

import pegged.grammar;

mixin(grammar(`
IEC62056:
    message         <- '/' manufacturer baudrate '\\' identification lineend lineend line+ '!' crc lineend
    manufacturer    <~ (Alpha / alpha) (Alpha / alpha) (Alpha / alpha)
    baudrate        <- digit
    identification  <~ (!lineend .)+
    line            <- obis (profilegeneric / data / register / mbus / clock / textmessage) lineend
    data            <- lparen integer rparen
    clock           <- timestamp
    register        <- measurement
    mbus            <- timestamp measurement
    profilegeneric  <- numvalues lparen obis rparen
    textmessage     <- lparen (!rparen .)* rparen
# A-B:C.D.E 
    obis            <-  ~(digit digit?) :'-' ~(digit digit? digit?) :':'
                        ~(digit digit? digit?) :'.' ~(digit digit? digit?) :'.' ~(digit digit? digit?)
    measurement     <- lparen value :'*' unit rparen
    timestamp       <- lparen datetime rparen
    numvalues       <- lparen ~(digit digit?) rparen
#  YYMMDDhhmmssX ( X = summer or winter)
    datetime        <~ digit digit digit digit digit digit digit digit digit digit digit digit ( 'S' / 'W' )
    value           <- floating / integer 
    integer         <~ digit+
    floating        <~ digit+ '.' digit+
    unit            <- "kWh" / "kW" / 'V' / 'A' / "m3" / "GJ"
    crc             <~ hexDigit hexDigit hexDigit hexDigit
    lparen          <: '('
    rparen          <: ')'
    lineend         <: "\r\n"
`));