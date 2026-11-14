#Область ПрограммныйИнтерфейс

// Возвращает соответствие: объект -> структура с полями Широта, Долгота, Источник, Точность, Адрес.
Функция КоординатыОбъектов(СписокОбъектов) Экспорт

	КоординатыПоОбъектам = Новый Соответствие;
	Если СписокОбъектов.Количество() = 0 Тогда
		Возврат КоординатыПоОбъектам;
	КонецЕсли;

	Запрос = Новый Запрос(
	"ВЫБРАТЬ
	|	Координаты.Объект КАК ОбъектКарты,
	|	Координаты.Широта КАК Широта,
	|	Координаты.Долгота КАК Долгота,
	|	Координаты.Источник КАК Источник,
	|	Координаты.Точность КАК Точность,
	|	Координаты.Адрес КАК Адрес
	|ИЗ
	|	РегистрСведений.кр_КоординатыОбъектов КАК Координаты
	|ГДЕ
	|	Координаты.Объект В (&СписокОбъектов)");
	Запрос.УстановитьПараметр("СписокОбъектов", СписокОбъектов);

	ВыборкаКоординат = Запрос.Выполнить().Выбрать();
	Пока ВыборкаКоординат.Следующий() Цикл
		ОписаниеКоординат = Новый Структура("Широта, Долгота, Источник, Точность, Адрес");
		ЗаполнитьЗначенияСвойств(ОписаниеКоординат, ВыборкаКоординат);
		КоординатыПоОбъектам.Вставить(ВыборкаКоординат.ОбъектКарты, ОписаниеКоординат);
	КонецЦикла;

	Возврат КоординатыПоОбъектам;

КонецФункции

// Ищет координаты адреса договора и записывает результат в регистр, в том числе "не найдено".
// При сбое сервиса ничего не записывает.
//
// Возвращаемое значение:
//  Структура - Итог ("Найдено", "НеНайдено" или "Сбой"), ОписаниеОшибки, ИзКэша.
//
Функция ОпределитьКоординатыДоговора(Договор, Адрес, ИнтервалМеждуЗапросамиМс = 1100) Экспорт

	РезультатГеокодирования = кр_Геокодер.КоординатыПоАдресу(Адрес, ИнтервалМеждуЗапросамиМс);
	РезультатДоговора = Новый Структура("Итог, ОписаниеОшибки, ИзКэша", "Сбой",
		РезультатГеокодирования.ОписаниеОшибки, РезультатГеокодирования.ИзКэша);

	Если РезультатГеокодирования.Найдено Тогда
		РезультатДоговора.Итог = "Найдено";
		ЗаписатьКоординаты(Договор, РезультатГеокодирования.Широта, РезультатГеокодирования.Долгота,
			"Nominatim", РезультатГеокодирования.Точность, Адрес);
	ИначеЕсли РезультатГеокодирования.ОписаниеОшибки = "Адрес не найден"
		Или РезультатГеокодирования.ОписаниеОшибки = "Пустой адрес" Тогда
		РезультатДоговора.Итог = "НеНайдено";
		ЗаписатьКоординаты(Договор, 0, 0, "Nominatim", РезультатГеокодирования.ОписаниеОшибки, Адрес);
	КонецЕсли;

	Возврат РезультатДоговора;

КонецФункции

Процедура ЗаписатьКоординаты(ОбъектКарты, Широта, Долгота, Источник, Точность, Адрес) Экспорт

	МенеджерЗаписи = РегистрыСведений.кр_КоординатыОбъектов.СоздатьМенеджерЗаписи();
	МенеджерЗаписи.Объект = ОбъектКарты;
	МенеджерЗаписи.Широта = Широта;
	МенеджерЗаписи.Долгота = Долгота;
	МенеджерЗаписи.Источник = Источник;
	МенеджерЗаписи.Точность = Точность;
	МенеджерЗаписи.Адрес = Адрес;
	МенеджерЗаписи.ДатаОпределения = ТекущаяДатаСеанса();
	МенеджерЗаписи.Записать();

КонецПроцедуры

// Точки - массив структур с полями Широта, Долгота, Заголовок, Описание, Индекс и необязательным Приблизительно (Булево).
// Приблизительные точки (найдены без дома или улицы) рисуются оранжевыми кружками.
// Точки с одинаковыми координатами разносятся по спирали на десятки метров, чтобы не закрывать друг друга.
// Индекс возвращается в событие ПриНажатии поля HTML ссылкой вида #point-<Индекс>.
// ПараметрыКарты - Структура, Неопределено - ТочкиНеКлиентов (массив структур Широта, Долгота, Заголовок, Описание, Источник)
//  и ГраницыРайоновJSON (строка, см. кр_ТочкиПродаж.ГраницыРайоновJSON).
Функция HTMLКарты(Точки, ПараметрыКарты = Неопределено) Экспорт

	ЗаписиТочек = Новый Массив;
	Для Каждого ТочкаКарты Из Точки Цикл
		ТочкаПриблизительная = ТочкаКарты.Свойство("Приблизительно") И ТочкаКарты.Приблизительно = Истина;
		ЗаписиТочек.Добавить(СтрШаблон("[%1,%2,""%3"",""%4"",%5,%6]",
			ФорматКоординаты(ТочкаКарты.Широта), ФорматКоординаты(ТочкаКарты.Долгота),
			ЭкранироватьДляJS(ТочкаКарты.Заголовок), ЭкранироватьДляJS(ТочкаКарты.Описание),
			Формат(ТочкаКарты.Индекс, "ЧН=0; ЧГ="), ?(ТочкаПриблизительная, "1", "0")));
	КонецЦикла;

	ЗаписиНеКлиентов = Новый Массив;
	ТекстГраниц = "[]";
	Если ПараметрыКарты <> Неопределено Тогда
		Для Каждого ТочкаНеКлиента Из ПараметрыКарты.ТочкиНеКлиентов Цикл
			ЗаписиНеКлиентов.Добавить(СтрШаблон("[%1,%2,""%3"",""%4"",""%5""]",
				ФорматКоординаты(ТочкаНеКлиента.Широта), ФорматКоординаты(ТочкаНеКлиента.Долгота),
				ЭкранироватьДляJS(ТочкаНеКлиента.Заголовок), ЭкранироватьДляJS(ТочкаНеКлиента.Описание),
				?(ТочкаНеКлиента.Свойство("Источник"), ЭкранироватьДляJS(ТочкаНеКлиента.Источник), "OpenStreetMap")));
		КонецЦикла;
		ТекстГраниц = ПараметрыКарты.ГраницыРайоновJSON;
	КонецЕсли;

	ТекстСтраницы =
	"<!DOCTYPE html>
	|<html><head>
	|<meta http-equiv=""X-UA-Compatible"" content=""IE=edge"">
	|<meta charset=""utf-8"">
	|<script>
	|var diagnosticErrors = [];
	|function showDiagnosticErrors() {
	|  var errorBox = document.getElementById('diagnostic-errors');
	|  if (!errorBox) { return; }
	|  errorBox.style.display = diagnosticErrors.length > 0 ? 'block' : 'none';
	|  errorBox.innerHTML = 'Ошибка карты (пришлите снимок разработчику):<br>' + diagnosticErrors.slice(-5).join('<br>');
	|}
	|window.onerror = function (errorMessage, sourceAddress, lineNumber, columnNumber) {
	|  var zoomText = (typeof map !== 'undefined' && map.getZoom) ? ', масштаб ' + map.getZoom() : '';
	|  diagnosticErrors.push(String(errorMessage) + ' (строка ' + lineNumber + ':' + (columnNumber || '?') + zoomText + ')');
	|  showDiagnosticErrors();
	|  return false;
	|};
	|function browserEngineName() {
	|  var agentText = navigator.userAgent;
	|  if (agentText.indexOf('Trident') >= 0 || agentText.indexOf('MSIE') >= 0) { return 'Internet Explorer'; }
	|  if (agentText.indexOf('Edg/') >= 0) { return 'Edge (Chromium)'; }
	|  if (agentText.indexOf('Chrome/') >= 0) { return 'Chromium'; }
	|  if (agentText.indexOf('AppleWebKit') >= 0) { return 'WebKit'; }
	|  return agentText.substring(0, 60);
	|}
	|</script>
	|<link rel=""stylesheet"" href=""https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"">
	|<script src=""https://unpkg.com/leaflet@1.9.4/dist/leaflet.js""></script>
	|<style>html, body, #map {height: 100%; margin: 0;} .point-link {font-weight: bold;}
	|.district-label {background: transparent; border: none; box-shadow: none; font: bold 11px sans-serif; color: #5f3dc4; text-shadow: 0 0 3px #fff;}
	|.district-label.city {color: #1864ab;}
	|.legend {background: #fff; padding: 6px 8px; font: 12px sans-serif; line-height: 18px; border-radius: 4px;}
	|.legend i {display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 6px;}
	|.legend .engine {color: #868e96; font-size: 10px;}
	|#diagnostic-errors {display: none; position: absolute; top: 10px; left: 60px; right: 230px; z-index: 2000; background: #fff5f5;
	|  border: 2px solid #e03131; color: #c92a2a; font: 12px sans-serif; padding: 6px 8px; border-radius: 4px;}</style>
	|</head><body><div id=""map""></div><div id=""diagnostic-errors""></div>
	|<script>
	|var points = [ТочкиКарты];
	|var otherPoints = [ТочкиНеКлиентов];
	|var districts = ГраницыРайонов;
	|var map = L.map('map', {preferCanvas: true});
	|map.createPane('approximatePane');
	|map.getPane('approximatePane').style.zIndex = 650;
	|L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
	|  maxZoom: 19,
	|  attribution: '&copy; <a href=""https://www.openstreetmap.org/copyright"">OpenStreetMap</a>'
	|}).addTo(map);
	|var clientLayer = L.layerGroup().addTo(map);
	|var otherLayer = L.layerGroup().addTo(map);
	|var regionLayer = L.layerGroup().addTo(map);
	|var cityLayer = L.layerGroup().addTo(map);
	|var regionLabels = [];
	|var cityLabels = [];
	|var manyPoints = points.length > 500;
	|var bounds = [];
	|var sameCoordinates = {};
	|for (var pointIndex = 0; pointIndex < points.length; pointIndex++) {
	|  var point = points[pointIndex];
	|  var coordinateKey = point[0] + ',' + point[1];
	|  var duplicateNumber = sameCoordinates[coordinateKey] || 0;
	|  sameCoordinates[coordinateKey] = duplicateNumber + 1;
	|  if (duplicateNumber > 0) {
	|    var ringAngle = duplicateNumber * 2.4;
	|    var ringRadius = 0.00025 * Math.sqrt(duplicateNumber);
	|    point[0] = point[0] + ringRadius * Math.cos(ringAngle);
	|    point[1] = point[1] + ringRadius * 1.8 * Math.sin(ringAngle);
	|  }
	|  var popupText = '<div>' + point[2] + '</div><div>' + point[3] + '</div>'
	|    + '<a class=""point-link"" href=""#point-' + point[4] + '"">Открыть</a>';
	|  if (point[5] === 1) {
	|    popupText = popupText + '<div><i>Точка приблизительная: найдена без дома или улицы</i></div>';
	|    L.circleMarker([point[0], point[1]], {pane: 'approximatePane', radius: manyPoints ? 5 : 8, color: '#d9480f', fillColor: '#fd7e14', fillOpacity: 0.9, weight: manyPoints ? 1 : 2}).addTo(clientLayer).bindPopup(popupText);
	|  } else if (manyPoints) {
	|    L.circleMarker([point[0], point[1]], {radius: 5, color: '#1864ab', fillColor: '#339af0', fillOpacity: 0.9, weight: 1}).addTo(clientLayer).bindPopup(popupText);
	|  } else {
	|    L.marker([point[0], point[1]]).addTo(clientLayer).bindPopup(popupText);
	|  }
	|  bounds.push([point[0], point[1]]);
	|}
	|for (var otherIndex = 0; otherIndex < otherPoints.length; otherIndex++) {
	|  var otherPoint = otherPoints[otherIndex];
	|  L.circleMarker([otherPoint[0], otherPoint[1]], {radius: 4, color: '#495057', fillColor: '#adb5bd', fillOpacity: 0.9, weight: 1})
	|    .addTo(otherLayer).bindPopup('<div><b>' + otherPoint[2] + '</b></div><div>' + otherPoint[3] + '</div><div><i>Не наш клиент, данные ' + otherPoint[4] + '</i></div>');
	|  if (points.length === 0) { bounds.push([otherPoint[0], otherPoint[1]]); }
	|}
	|for (var districtIndex = 0; districtIndex < districts.length; districtIndex++) {
	|  var district = districts[districtIndex];
	|  var isCity = district.level === '9';
	|  var targetLayer = isCity ? cityLayer : regionLayer;
	|  var minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
	|  for (var lineIndex = 0; lineIndex < district.lines.length; lineIndex++) {
	|    var flatLine = district.lines[lineIndex];
	|    var lineCoordinates = [];
	|    for (var coordinateIndex = 0; coordinateIndex + 1 < flatLine.length; coordinateIndex += 2) {
	|      var latitude = flatLine[coordinateIndex], longitude = flatLine[coordinateIndex + 1];
	|      lineCoordinates.push([latitude, longitude]);
	|      if (latitude < minLat) { minLat = latitude; } if (latitude > maxLat) { maxLat = latitude; }
	|      if (longitude < minLon) { minLon = longitude; } if (longitude > maxLon) { maxLon = longitude; }
	|    }
	|    L.polyline(lineCoordinates, isCity ? {color: '#1c7ed6', weight: 2, dashArray: '6 4', interactive: false} : {color: '#7048e8', weight: 2, opacity: 0.7, interactive: false}).addTo(targetLayer);
	|  }
	|  if (maxLat >= minLat) {
	|    var districtName = (district.name || '').replace(/^муниципальный округ (.+)$/, '$1 м. о.').replace(' муниципальный округ', ' м. о.').replace(' городской округ', ' г. о.');
	|    var districtLabel = L.tooltip({permanent: true, direction: 'center', className: 'district-label' + (isCity ? ' city' : '')})
	|      .setLatLng([(minLat + maxLat) / 2, (minLon + maxLon) / 2]).setContent(districtName);
	|    (isCity ? cityLabels : regionLabels).push({label: districtLabel, layer: targetLayer});
	|  }
	|}
	|function updateDistrictLabels() {
	|  var zoomLevel = map.getZoom();
	|  var groups = [[regionLabels, zoomLevel >= 7 && zoomLevel <= 11], [cityLabels, zoomLevel >= 11]];
	|  for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
	|    var labelGroup = groups[groupIndex][0], showLabels = groups[groupIndex][1];
	|    for (var labelIndex = 0; labelIndex < labelGroup.length; labelIndex++) {
	|      var labelItem = labelGroup[labelIndex];
	|      if (showLabels && map.hasLayer(labelItem.layer)) { labelItem.label.addTo(map); } else { map.removeLayer(labelItem.label); }
	|    }
	|  }
	|}
	|map.on('zoomend overlayadd overlayremove', updateDistrictLabels);
	|var overlays = {'Наши клиенты': clientLayer};
	|if (otherPoints.length > 0) { overlays['Не клиенты (' + otherPoints.length + ')'] = otherLayer; }
	|if (districts.length > 0) { overlays['Округа края'] = regionLayer; overlays['Районы Перми'] = cityLayer; }
	|L.control.layers(null, overlays, {collapsed: false}).addTo(map);
	|var legend = L.control({position: 'bottomleft'});
	|legend.onAdd = function () {
	|  var legendBox = L.DomUtil.create('div', 'legend');
	|  legendBox.innerHTML = '<div><i style=""background:#339af0""></i>Наш клиент</div><div><i style=""background:#fd7e14""></i>Клиент, точка приблизительная</div>'
	|    + (otherPoints.length > 0 ? '<div><i style=""background:#adb5bd""></i>Не клиент</div>' : '')
	|    + '<div class=""engine"" id=""engine-line""></div>';
	|  return legendBox;
	|};
	|legend.addTo(map);
	|function updateEngineLine() {
	|  var engineLine = document.getElementById('engine-line');
	|  if (engineLine) { engineLine.innerHTML = browserEngineName() + ', масштаб ' + map.getZoom(); }
	|}
	|map.on('zoomend', updateEngineLine);
	|if (bounds.length > 0) { map.fitBounds(bounds, {padding: [30, 30], maxZoom: 16}); }
	|else { map.setView([58.01, 56.25], 10); }
	|updateDistrictLabels();
	|updateEngineLine();
	|showDiagnosticErrors();
	|</script></body></html>";

	ТекстСтраницы = СтрЗаменить(ТекстСтраницы, "[ТочкиКарты]", "[" + СтрСоединить(ЗаписиТочек, ",") + "]");
	ТекстСтраницы = СтрЗаменить(ТекстСтраницы, "[ТочкиНеКлиентов]", "[" + СтрСоединить(ЗаписиНеКлиентов, ",") + "]");
	Возврат СтрЗаменить(ТекстСтраницы, "ГраницыРайонов;", ТекстГраниц + ";");

КонецФункции

// Возвращает индекс точки из ссылки #point-<Индекс> или Неопределено.
Функция ИндексТочкиПоСсылке(Ссылка) Экспорт

	Маркер = "#point-";
	ПозицияМаркера = СтрНайти(Ссылка, Маркер);
	Если ПозицияМаркера = 0 Тогда
		Возврат Неопределено;
	КонецЕсли;

	ТекстИндекса = Сред(Ссылка, ПозицияМаркера + СтрДлина(Маркер));
	ОписаниеЧисла = Новый ОписаниеТипов("Число");
	ИндексТочки = ОписаниеЧисла.ПривестиЗначение(ТекстИндекса);
	Если ИндексТочки = 0 И ТекстИндекса <> "0" Тогда
		Возврат Неопределено;
	КонецЕсли;

	Возврат ИндексТочки;

КонецФункции

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

Функция ФорматКоординаты(Координата)

	Возврат Формат(Координата, "ЧДЦ=6; ЧРД=.; ЧГ=; ЧН=0");

КонецФункции

Функция ЭкранироватьДляJS(ИсходныйТекст)

	ТекстДляJS = Строка(ИсходныйТекст);
	ТекстДляJS = СтрЗаменить(ТекстДляJS, "\", "\\");
	ТекстДляJS = СтрЗаменить(ТекстДляJS, """", "\""");
	ТекстДляJS = СтрЗаменить(ТекстДляJS, "<", "&lt;");
	ТекстДляJS = СтрЗаменить(ТекстДляJS, ">", "&gt;");
	ТекстДляJS = СтрЗаменить(ТекстДляJS, Символы.ПС, " ");
	ТекстДляJS = СтрЗаменить(ТекстДляJS, Символы.ВК, " ");

	Возврат ТекстДляJS;

КонецФункции

#КонецОбласти
