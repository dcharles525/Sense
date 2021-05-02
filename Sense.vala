//============================================================+
// File name   : Sense.vala
// Last Update : 2021-05-01
//
// Version: 0.1.0
//
// Description : This is a small abstraction layer for the /sys/class/hwmon/ modules in the linux kernel to extract 
// temperature data. Our Temperature struct has an average_core_temp which is calculated within, and seemed to be a 
// bit more accurate, however the first core within the raw_data file seems to be the one calculated by the kernel 
// driver. Currently this only supports Intel and AMD chips, but I might add more as needed.
//
// NOTE: I have not tested on an amd chip. 
//
// Author: David Johnson
//============================================================+

public class Sense{
  
  public struct Core{
    public string coreLabel;
    public double currentTemp;
  }

  public struct Temperature {
    public string cpuType; //coretemp (Intel) or k10temp (AMD)
    public double averageCoreTemp;
    public Array<Core?> rawData; 
  }

  public Temperature temperatureStruct;

  public Sense () {
    
    Array<Core?> coreArray = new Array<Core?>();

    temperatureStruct = {
      "",
      0,
      coreArray
    };

    collectData ();
  
  }
  
  /*
  * Opens files 
  *
  * Small private function to open kernel files to get our data from.
  *
  * @param string filename
  * @return string
  */ 
  private string openFile (string filename) {

    try {
      
      string read;
      FileUtils.get_contents (filename, out read);
      
      return read;

    } catch (FileError e) {
      
      stderr.printf ("%s\n", e.message);
      return "0";

    }

  }
  
  /*
  * Collects Temperature Data 
  *
  * The function first begins traversing the hwmon directories looking for the processor, once found we find the 
  * real average of each core and set information to our struct. 
  *
  * @return void
  */ 
  public void collectData () {
    
    //clear array if collect_data is in a loop
    this.temperatureStruct.rawData.set_size (0);
    double totalTemperature = 0;
    int hwmonCounter = 0, temperatureCounter = 1;
    bool hwmonTraversing = true, coreTraversing = true;

    while (hwmonTraversing) {
      
      string path = "/sys/class/hwmon/hwmon".concat (hwmonCounter.to_string (),"/");
      string hwmonNamePath = path.concat ("name");

      if (!FileUtils.test (hwmonNamePath, FileUtils.EXISTS)) {

        hwmonTraversing = false;
        continue;

      }
        
      //Note we strip out newlines
      string cpuName = openFile (hwmonNamePath).replace ("\n","");
      
      //If we find either intel or amd chip
      if (cpuName != "coretemp" && cpuName != "k10temp") {

        hwmonCounter++;
        continue;

      }

      this.temperatureStruct.cpuType = cpuName;

      while (coreTraversing) {
        
        string coreTemperaturePath = path.concat ("temp", temperatureCounter.to_string (), "_input");
        string coreLabelPath = path.concat ("temp", temperatureCounter.to_string (), "_label");

        if (!FileUtils.test (coreTemperaturePath, FileUtils.EXISTS)) {

          coreTraversing = false;
          continue;

        }

        double coreTemperature = double.parse (openFile (coreTemperaturePath));
        //Note we strip out newlines
        string coreLabel = openFile (coreLabelPath).replace ("\n","");
      
        totalTemperature += coreTemperature;
        temperatureCounter++;
        
        Core core = {
          coreLabel,
          coreTemperature,
        };

        this.temperatureStruct.rawData.append_val (core);

      }
      
      //Gets the true average based on the data, seems to be fairly accurate.
      this.temperatureStruct.averageCoreTemp = totalTemperature / (temperatureCounter - 1);
      hwmonCounter++;

    }

  }

}
  
//Example of how to handle the class.

void main (string[] args) {

  Sense senseInstance = new Sense ();
  
  string cpuType = senseInstance.temperatureStruct.cpuType;
  double rawTemperature = senseInstance.temperatureStruct.averageCoreTemp;
  double fahrenheit = (rawTemperature / 1000) * (9.00 / 5.00) + 32;

  stdout.printf ("%s \n", "|||||||||||||||||| CPU INFO |||||||||||||||||||||");
  stdout.printf ("%s | %f \n", cpuType, fahrenheit);

  stdout.printf ("%s \n", "|||||||||||||||||| CORE INFO |||||||||||||||||||||");

  for (int i = 0; i < senseInstance.temperatureStruct.rawData.length; i++) {
  
    string coreLabel = senseInstance.temperatureStruct.rawData.index (i).coreLabel;
    double currentTemperature = senseInstance.temperatureStruct.rawData.index (i).currentTemp;
    
    currentTemperature = (currentTemperature / 1000) * (9.00 / 5.00) + 32;

    stdout.printf ("%s | Current: %f \n", coreLabel, currentTemperature);

  }

}
