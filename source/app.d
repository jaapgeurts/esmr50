import std.stdio;
import std.conv;
import std.array;
import std.format;
import std.datetime.systime : SysTime, Clock;

import std.file : readText;

import dserial;

import iec62056;

import AsyncClient;
import ConnectOptions;
import Message;
import Token;
import MqttException : MqttException;
import Callback;
import ActionListener;

private immutable TOPIC_ELECTRICITY_TOTAL_PEAK = "energy/electricity/totalpeak";
private immutable TOPIC_ELECTRICITY_TOTAL_OFF = "energy/electricity/totaloff";
private immutable TOPIC_ELECTRICITY_CURRENT = "energy/electricity/current";
private immutable TOPIC_GAS_TOTAL = "energy/gas/total";
private immutable TOPIC_GAS_CURRENT = "energy/gas/current";


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

private MqttAsyncClient client;
private MqttConnectOptions opt;

int main() {

    writeln("COSEM Smart meter decoder");
    writeln("©2022 Jaap Geurts");

    // setup mqtt
    string serverURI = "tcp://192.168.20.251:8883";
    client = new MqttAsyncClient(serverURI, "energylogger");
    if (!client.isOK()) {
        stderr.writeln("Error creating MQTT client.");
        return 1;
    }

    opt = new MqttConnectOptions("NhaMinh","ValleStap74#");
    opt.getOptionsPtr().automaticReconnect = true;

    try {
        MqttToken tok = client.connect(opt, null, null);
        tok.waitForCompletion();
    }
    catch (MqttException exc) {
        stderr.writeln("Cannot connect: ", exc.getReasonCode());
        return 1;
    }

    DSerial serialPort = new DSerial(ttyName, 115200);
    serialPort.setBlockingMode(DSerial.BlockingMode.Blocking);
    serialPort.setTimeout(200); // 200 millis
    serialPort.open();

    while (true) {

        //string telegram = readText("esmr50telegram.txt");
        string telegram = readline(serialPort);
        auto parseTree1 = IEC62056(telegram);
        if (!parseTree1.successful) {
            writeln(telegram);
            writeln(parseTree1);
            break;
        }

        float totalPower,totalGas;
        int currentPower;
        foreach (ref child; parseTree1.children[0]) {
            if (child.name == "IEC62056.line") {
                if (child.matches[0] == "1-0:1.8.1") {
                    totalPower = to!float(child.matches[1]);
                }
                if (child.matches[0] == "1-0:1.7.0") {
                    currentPower = to!int(to!float(child.matches[1]) * 1000);
                }
                if (child.matches[0] == "0-1:24.2.1") {
                    totalGas = to!float(child.matches[2]);
                }
            }
        }
        // SysTime currentTime = Clock.currTime();
        // writeln(currentTime.toSimpleString(),": ",totalPower,"kWh, ",currentPower,"W");

        MqttDeliveryToken token = client.publish(TOPIC_ELECTRICITY_CURRENT, format("%d%s",currentPower,"W"), 1, true);
        token.waitForCompletion();
        token = client.publish(TOPIC_ELECTRICITY_TOTAL_PEAK, format("%f%s",totalPower,"kWh"), 1, true);
        token.waitForCompletion();
        token = client.publish(TOPIC_GAS_TOTAL, format("%f%s",totalGas,"m3"), 1, true);
        token.waitForCompletion();
    }
    serialPort.close();
    return 1;
}

private string readline(DSerial serial) {

    auto strBuilder = appender!string;
    strBuilder.reserve(1024);

    ubyte c;
    bool started = false;
    while (serial.read(c) == 1) {
        if (c == '/') {
            started = true;
        }
        if (started)
          strBuilder.put(c);
        if (c == '!')
            break;
    }
    for(int i=0;i<6;i++) {
        serial.read(c);
        strBuilder.put(c);
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
