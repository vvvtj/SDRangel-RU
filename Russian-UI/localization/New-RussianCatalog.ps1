$ErrorActionPreference='Stop'
$messages=[ordered]@{
 'File'='Файл';'&File'='&Файл';'View'='Вид';'&View'='&Вид';'Workspaces'='Рабочие области';'Preferences'='Настройки';'Help'='Справка';'Exit'='Выход';'&Exit'='&Выход';
 'New'='Создать';'View all'='Показать все';'Remove empty'='Удалить пустые';'Configurations'='Конфигурации';'Audio'='Звук';'Graphics'='Графика';'Logging'='Журнал';'My Position'='Моё положение';
 'Devices'='Устройства';'User arguments'='Аргументы устройства';'Commands'='Команды';'Save all'='Сохранить всё';'Loaded Plugins'='Загруженные плагины';'About'='О программе';
 'Done'='Готово';'All current settings saved'='Все текущие настройки сохранены';'Date'='Дата';'Current date/time'='Текущие дата и время';
 'Save'='Сохранить';'Load'='Загрузить';'Delete'='Удалить';'Rename'='Переименовать';'Import'='Импорт';'Export'='Экспорт';'Close'='Закрыть';'Cancel'='Отмена';'Apply'='Применить';'OK'='ОК';
 'Name'='Название';'Description'='Описание';'Group'='Группа';'Update'='Обновить';'Frequency'='Частота';'Center frequency'='Центральная частота';'Sample rate'='Частота дискр.';'Bandwidth'='Полоса';'Gain'='Усиление';
 'Manual'='Ручное';'Antenna'='Антенна';'Decimation'='Децимация';'Stream'='Поток';'Spectrum'='Спектр';'Waterfall'='Водопад';'FFT size'='Размер FFT';'Zoom'='Масштаб';'Grid'='Сетка';
 'Reference level'='Опорный уровень';'Power range'='Диапазон уровней';'Averaging'='Усреднение';'Max hold'='Удержание максимума';'Histogram'='Гистограмма';
 'Start/Stop Rx'='Пуск/стоп приёма (RX)';'Start/Stop Tx'='Пуск/стоп передачи (TX)';'Rx/Tx settings selection'='Выбор настроек RX/TX';'Stream settings selection'='Выбор потока';
 'Rx/Tx spectrum display selection'='Спектр RX/TX';'Stream spectrum display selection'='Поток для спектра';'Lock both streams gains'='Общее усиление потоков';
 'Rx analog filter bandwidth'='Полоса фильтра RX';'Rx gain mode'='Режим усиления RX';'Rx global manual gain'='Усиление RX вручную';'Device sample rate'='Частота дискретизации устройства';
 'Remove device set %1?'='Удалить набор устройств %1?'
}
$contexts=@('MainWindow','ConfigurationsDialog','ConfigurationDialog','DeviceGUI','GLSpectrumGUI','SpectrumGUI','PlutoSDRInputGUI','PlutoSDRMIMOGUI')
$options=New-Object Xml.XmlWriterSettings;$options.Encoding=New-Object Text.UTF8Encoding $false;$options.Indent=$true
$writer=[Xml.XmlWriter]::Create((Join-Path $PSScriptRoot 'sdrangel_ru.ts'),$options)
try {
 $writer.WriteStartDocument();$writer.WriteDocType('TS',$null,$null,$null);$writer.WriteStartElement('TS');$writer.WriteAttributeString('version','2.1');$writer.WriteAttributeString('language','ru_RU');$writer.WriteAttributeString('sourcelanguage','en_US')
 foreach($context in $contexts) {
  $writer.WriteStartElement('context');$writer.WriteElementString('name',$context)
  foreach($source in $messages.Keys){$writer.WriteStartElement('message');$writer.WriteElementString('source',$source);$writer.WriteElementString('translation',$messages[$source]);$writer.WriteEndElement()}
  $writer.WriteEndElement()
 }
 $writer.WriteEndElement();$writer.WriteEndDocument()
}finally{$writer.Dispose()}
'Seed TS written. Exact source context/coverage must still be checked with full checkout and lupdate.'
