import std.stdio;
import std.conv;
import std.array;

import std.file : readText;

import dserial;

import iec62056;

/* 
 * Description: Application to read ESMR-5 messages from smart energy meter
 *
 * Author: Jaap Geurts 
 * Date: 26/09/2022
 *
 * See reference documentation:
 * https://www.netbeheernederland.nl/_upload/Files/Slimme_meter_15_a727fce1f1.pdf (chapter 6)
 * https://www.dlms.com/files/Blue_Book_Edition_13-Excerpt.pdf (chapter 7)
 * https://www.ungelesen.net/protagWork/media/downloads/solar-steuerung/iec62056-21%7Bed1.0%7Den_.pdf (chapter 6)
 */

/* 
  A-B:C.D.E.F
- The A group specifies the medium (0=abstract objects, 1=electricity, 6=heat, 7=gas, 8=water ...)
- The B group specifies the channel. Each device with multiple channels generating measurement results, can separate the results into the channels.
- The C group specifies the physical value (current, voltage, energy, level, temperature, ...)
- The D group specifies the quantity computation result of specific algorythm
- The E group specifies the measurement type defined by groups A to D into individual measurements (e.g. switching ranges)
- The F group separates the results partly defined by groups A to E. The typical usage is the specification of individual time ranges.
*/

struct OBIS {
    int medium;
    int channel;
    int physicalQuantity;
    int computationResult;
    int measurementType;
    int separate;
}

string ttyName = "/dev/ttyS4";

// Parse state is per line
enum ParseState {
    Start,
    EmptyLine,
    Data,
    CRC
}

void main() {

    writeln("COSEM Smart meter decoder");
    writeln("©2022 Jaap Geurts");

    DSerial serialPort = new DSerial(ttyName, 115200);
    serialPort.setBlockingMode(DSerial.BlockingMode.TimedImmediately);
    serialPort.setTimeout(200); // 200 millis
    serialPort.open();

    while (true) {

        //string telegram = readText("esmr50telegram.txt");
        string telegram = readline(serialPort);
        auto parseTree1 = IEC62056(telegram);
        //writeln(parseTree1);

        foreach (ref child; parseTree1.children[0]) {
            if (child.name == "IEC62056.line") {
                if (child.matches[0] == "1-0:1.8.1") {
                    writeln(child.matches[1], child.matches[2]);
                }
            }
        }

    }
}

private string readline(DSerial serial) {

    auto strBuilder = appender!string;
    strBuilder.reserve(1024);

    ubyte c;

    while (serial.read(c) == 1) {
        if (c == '/') {
            strBuilder.put(c);
        }
        if (c == '!')
            break;
    }
    return strBuilder.data;
}

// OBIS parseOBIS(string section) {
//   OBIS obis;
//   obis.medium = to!int(section[0..1]);
//   if (section[1..2] != '-')
//       throw new ParseException();
//   obis.channel = to!int(section[2..3]);
// }
