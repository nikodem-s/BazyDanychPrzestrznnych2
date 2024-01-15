function Download-Zip-File([string]$url, [string]$directory){
    Invoke-WebRequest $url -OutFile $directory
}

function Extract-Files-From-Zip([string]$fileDirectory, [string]$destDirectory){
   $password = ConvertTo-SecureString "bdp2agh" -AsPlainText -Force;
   Expand-7Zip -ArchiveFileName $fileDirectory -TargetPath $destDirectory -SecurePassword $password;
}

function Read-And-Validate-File([string]$file, $main_directory, $fileName){
    $num_rows = (Get-Content $file).Length;
    $header = (Get-Content -Path $file -TotalCount $num_rows)[0];
    $data = [System.Collections.ArrayList]@();
    $data_rows = @(Get-Content -Path $file -TotalCount $num_rows) | Select-Object -Skip 1;
    $bad_rows = [System.Collections.ArrayList]@();

    # wpisanie elementow do dynamicznej tablicy, filtracja pustych wierszy, sprawdzenie czy wiersz zawiera litery oraz cyfry.
    for($i=0; $i -lt $data_rows.Length; $i++){
        $row = $data_rows[$i];
        if($row -match "[a-zA-Z]" -and $row -match "[0-9]"){
            $arrayID = $data.Add($data_rows[$i]);
        }
        else{
            $arrayID = $bad_rows.Add($data_rows[$i]);
        }
    }
    
    # sprawdzenei zduplukowanych wierszy
    $unique =[System.Collections.ArrayList]@();

    foreach($element in $data){
        if($unique.Contains($element) -eq $false){
            $arrayID = $unique.Add($element);
        }
        else{
            $arrayID = $bad_rows.Add($element);
        }
    }
    $data = [System.Collections.ArrayList]@($data | Select -unique);
    
    # liczba kolumn
    $col_num = $header.Split('|').Count

    # pusta lista, dlatego ze z usuwanie z listy w powershellu jest ciężkie, dlatego lepeij stworzyc tymczasową listę
    $data_tmp = [System.Collections.ArrayList]@();

    foreach($element in $data){
        if($element.Split('|').Count -gt $col_num -or $element.Split('|').Count -lt $col_num){
            $arrayID = $bad_rows.Add($element);
        }
        else{
            $arrayID = $data_tmp.Add($element);
        }
    }
    $data = $data_tmp;
    Remove-Variable -Name data_tmp;
    
    # OrderQuantity - 4 oraz usuniecie gdzie jest wartość w SecretCode
    $data_tmp = [System.Collections.ArrayList]@();
    $numerator = 1;
    foreach($element in $data){
        $element_content = $element.Split('|');
        if($element_content[4] -gt 100){
            $arrayID = $bad_rows.Add($element);
        }
        else{
            if($element_content[6] -eq ''){
                $customer = $element.Split('|')[2];
                $customer_name = $customer.Replace('"', '').Split(',')[1];
                $customer_surname = $customer.Replace('"', '').Split(',')[0]
                $row = "$($numerator)|$($element_content[0])|$($element_content[1])|$($customer_name)|$($customer_surname)|$($element_content[3])|$($element_content[4])|$($element_content[5])|$($element_content[6])"
                if($customer_surname.Length -lt 20){
                    $arrayID = $data_tmp.Add($row);
                    $numerator = $numerator + 1;
                    }
            }
            else{
                $arrayID = $bad_rows.Add($element);
            }
        }
    }
    $headers = "client_id|ProductKey|CurrencyAlternateKey|FIRST_NAME|LAST_NAME|OrderDateKey|OrderQuantity|UnitPrice|SecretCode";
    $data = $data_tmp;
    Remove-Variable -Name data_tmp;
    
    # zapisanie pliku .bad
    $Date = Get-Date;
    $DateStr = $Date.ToString("yyyyMMdd");
    New-Item -Path $main_directory -Name ("InternetSales_new_bad"+"_"+"$dateStr"+".txt") -ItemType "file" -Force;
    for($i=-1; $i -lt $bad_rows.Count; $i++){
        Add-Content -Path ($main_directory + "\InternetSales_new_bad"+"_"+"$dateStr"+".txt") -Value ($bad_rows[$i]);
    }

    # wpisanie zmian w pliku nowym w podkatalogu PROCESSED
    $Date = Get-Date;
    $DateStr = $Date.ToString("yyyyMMdd");
    New-Item -Path $main_directory -Name "PROCESSED" -ItemType "directory" -Force;
    New-Item -Path ($main_directory + "\PROCESSED") -Name ("$dateStr"+"_"+"$fileName") -ItemType "file" -Force;
    for($i=-1; $i -lt $data.Count; $i++){
        if($i -eq -1){
            Set-Content -Path ($main_directory + "\PROCESSED\" + "$dateStr"+"_"+"$fileName") -Value ($headers);
        }
        elseif($i -lt $data.Count-2){
            Add-Content -Path ($main_directory + "\PROCESSED\" + "$dateStr"+"_"+"$fileName") -Value ($data[$i]);
        }
        else{
            Add-Content -Path ($main_directory + "\PROCESSED\" + "$dateStr"+"_"+"$fileName") -Value ($data[$i]);
        }
    }
    (Get-Content ($main_directory + "\PROCESSED\" + "$dateStr"+"_"+"$fileName")).Replace(',', '.') | Set-Content ($main_directory + "\PROCESSED\" + "$dateStr"+"_"+"$fileName");
    
}

function Create-Table-Database($table_name){
    Set-Location 'C:\Program Files\PostgreSQL\13\bin\'
    $password = "admin";
    $env:PGPASSWORD = $password;
    $Database = "s401529"
    .\psql.exe -U testowy -d $Database -w -c "CREATE TABLE IF NOT EXISTS $table_name (client_id INT,ProductKey INT, CurrencyAlternateKey VARCHAR(3), FIRST_NAME VARCHAR(40), LAST_NAME VARCHAR(40), OrderDateKey VARCHAR(20), OrderQuantity INT, UnitPrice NUMERIC, SecretCode VARCHAR(10))"
}
function Insert_Processed_Values_To_Table($table_name, $path ,$file_path){
    Set-Location 'C:\Program Files\PostgreSQL\13\bin\';
    $Database = "s401529";
    $password = "admin";
    $env:PGPASSWORD = $password;
    .\psql.exe -U testowy -d $Database -w -c "COPY $table_name FROM '$path\PROCESSED\$file_path' (FORMAT CSV,DELIMITER('|'), HEADER true)";
}
function Update_SecretCode_Column($table_name){
    Set-Location 'C:\Program Files\PostgreSQL\13\bin\';
    $Database = "s401529";
    $password = "admin";
    $env:PGPASSWORD = $password;
    $count = .\psql.exe -U testowy -d $Database -w -c "SELECT * FROM $table_name";
    $length_of_database = $count.Length;
    
    for($i=1; $i -le ($length_of_database-4); $i++){
        Set-Location 'C:\Program Files\PostgreSQL\13\bin\';
        .\psql.exe -U testowy -d $Database -w -c "UPDATE $table_name SET secretcode=SUBSTRING(MD5(RANDOM()::text), 1, 10) WHERE client_id=$i";
    }
}
function Export_And_Compress($table_name, $path ,$path_file){
    New-Item -Path ($path + "\PROCESSED") -Name "CUSTOMERS_401529.csv" -ItemType "file" -Force;
    Set-Location 'C:\Program Files\PostgreSQL\13\bin\';
    $Database = "s401529";
    $password = "admin";
    $env:PGPASSWORD = $password;
    .\psql.exe -U testowy -d $Database -w -c "COPY $table_name TO '$path\PROCESSED\$path_file' DELIMITER '|' CSV HEADER";

    $compress = @{
    Path = "$path\PROCESSED\$path_file"
    CompressionLevel = "Fastest"
    DestinationPath = "$path\PROCESSED\CUSTOMERS_401529.zip"
}
Compress-Archive @compress
}
$fileName = 'InternetSales_new.txt';
$url = 'https://home.agh.edu.pl/~wsarlej/dyd/bdp2/materialy/cw10/InternetSales_new.zip';
$directory = 'D:\mgr-sem2\BDP2\zaj10\dane.zip';
$destDirectory = 'D:\mgr-sem2\BDP2\zaj10\dane';
$index_number = "401529";
$main_directory ='D:\mgr-sem2\BDP2\zaj10'
$processed_directory = $main_directory + "\PROCESSED";

#Download-Zip-File $url $directory;
#Extract-Files-From-Zip $directory $destDirectory;
#Read-And-Validate-File ($destDirectory + '\' + $fileName) $main_directory $fileName;
#Create-Table-Database "CUSTOMERS_$index_number";
#Insert_Processed_Values_To_Table ("CUSTOMERS_$index_number") $main_directory (Get-ChildItem $processed_directory)[0];
#Update_SecretCode_Column ("CUSTOMERS_$index_number")
#Export_And_Compress ("CUSTOMERS_$index_number") $main_directory "CUSTOMERS_401529.csv"

$Date = Get-Date;
$DateStr_main = $Date.ToString("yyyyMMdd");
New-Item -Path ($main_directory + "\PROCESSED") -Name ("$DateStr_main"+"_"+"skrypt.log") -ItemType "file" -Force;

Download-Zip-File $url $directory;
if($?)
{
    $Date = Get-Date;
    $DateStr = $Date.ToString("yyyyMMdd");
   "DOWNLOADING SUCEED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("DOWNLOADING SUCEED $DateStr");
}
else
{
   "DOWNLOADING FAILED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("DOWNLOADING FAILED $DateStr");
}

Extract-Files-From-Zip $directory $destDirectory;
if($?)
{
    $Date = Get-Date;
    $DateStr = $Date.ToString("yyyyMMdd");
   "EXTRACTING SUCEED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("EXTRACTING SUCEED $DateStr");
}
else
{
   "EXTRACTING FAILED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("EXTRACTING FAILED $DateStr");
}
Read-And-Validate-File ($destDirectory + '\' + $fileName) $main_directory $fileName;
if($?)
{
    $Date = Get-Date;
    $DateStr = $Date.ToString("yyyyMMdd");
   "VALIDATION SUCEED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("VALIDATION SUCEED $DateStr");
}
else
{
   "VALIDATION FAILED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("VALIDATION FAILED $DateStr");
}
Create-Table-Database "CUSTOMERS_$index_number";
if($?)
{
    $Date = Get-Date;
    $DateStr = $Date.ToString("yyyyMMdd");
   "TABLE CREATION SUCEED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("TABLE CREATION SUCEED $DateStr");
}
else
{
   "TABLE CREATION FAILED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("TABLE CREATION FAILED $DateStr");
}
Insert_Processed_Values_To_Table ("CUSTOMERS_$index_number") $main_directory (Get-ChildItem $processed_directory)[0];
if($?)
{
    $Date = Get-Date;
    $DateStr = $Date.ToString("yyyyMMdd");
   "INSERTING SUCEED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("INSERTING SUCEED $DateStr");
}
else
{
   "INSERTING FAILED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("INSERTING FAILED $DateStr");
}
Update_SecretCode_Column ("CUSTOMERS_$index_number")
if($?)
{
    $Date = Get-Date;
    $DateStr = $Date.ToString("yyyyMMdd");
   "SECRET CODE SUCEED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("SECRET CODE SUCEED $DateStr");
}
else
{
   "SECRET CODE FAILED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("SECRET CODE FAILED $DateStr");
}
Export_And_Compress ("CUSTOMERS_$index_number") $main_directory "CUSTOMERS_401529.csv"
if($?)
{
    $Date = Get-Date;
    $DateStr = $Date.ToString("yyyyMMdd");
   "EXPORT AND COMPRESS SUCEED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("EXPORT AND COMPRESS SUCEED $DateStr");
}
else
{
   "EXPORT AND COMPRESS FAILED $DateStr"
   Add-Content -Path ($main_directory + "\PROCESSED\" + ("$DateStr_main"+"_"+"skrypt.log")) -Value ("EXPORT AND COMPRESS FAILED $DateStr");
}
