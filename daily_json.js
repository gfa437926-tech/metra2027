// daily_json.js - معالجة البيانات بصيغة JSON للملخص اليومي

// تصدير البيانات بصيغة JSON
function exportToJSON(formData, includeMetadata = true) {
    try {
        const exportData = { ...formData };
        
        if (includeMetadata) {
            exportData.metadata = {
                export_date: new Date().toISOString(),
                version: '1.0',
                format: 'daily_weather_report',
                generated_by: 'نظام إدارة البيانات الجوية'
            };
        }
        
        const jsonString = JSON.stringify(exportData, null, 2);
        return jsonString;
        
    } catch (error) {
        console.error('خطأ في تصدير JSON:', error);
        throw new Error('فشل في تصدير البيانات بصيغة JSON');
    }
}

// تحميل البيانات من JSON
function importFromJSON(jsonString) {
    try {
        const data = JSON.parse(jsonString);
        
        // التحقق من صحة الهيكل الأساسي
        if (!isValidDailyReport(data)) {
            throw new Error('صيغة JSON غير صالحة لتقرير الطقس اليومي');
        }
        
        return data;
        
    } catch (error) {
        console.error('خطأ في تحميل JSON:', error);
        throw new Error('فشل في تحميل البيانات من JSON: ' + error.message);
    }
}

// التحقق من صحة هيكل التقرير
function isValidDailyReport(data) {
    const requiredFields = [
        'station', 'observer_name', 'report_type'
    ];
    
    for (let field of requiredFields) {
        if (data[field] === undefined || data[field] === null) {
            return false;
        }
    }
    
    return true;
}

// تنزيل ملف JSON
function downloadJSON(formData, filename = null) {
    try {
        const jsonString = exportToJSON(formData, true);
        const blob = new Blob([jsonString], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        
        if (!filename) {
            const date = new Date().toISOString().split('T')[0];
            filename = `daily_report_${date}.json`;
        }
        
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        
        if (typeof showNotification === 'function') {
            showNotification('تم تصدير الملخص بصيغة JSON بنجاح', 'success');
        }
        return true;
        
    } catch (error) {
        console.error('خطأ في تنزيل JSON:', error);
        if (typeof showNotification === 'function') {
            showNotification('فشل في تصدير الملخص', 'error');
        }
        return false;
    }
}

// تحميل ملف JSON
function uploadJSON(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        
        reader.onload = function(e) {
            try {
                const jsonString = e.target.result;
                const data = importFromJSON(jsonString);
                resolve(data);
            } catch (error) {
                reject(error);
            }
        };
        
        reader.onerror = function() {
            reject(new Error('فشل في قراءة الملف'));
        };
        
        reader.readAsText(file);
    });
}

// تعبئة النموذج من بيانات JSON (محدث لدعم القيمة null)
function fillFormFromJSON(data) {
    try {
        // تعبئة الحقول الأساسية
        if (data.min_temperature !== null && data.min_temperature !== undefined) {
            document.getElementById('minTemp').value = data.min_temperature;
        }
        if (data.max_temperature !== null && data.max_temperature !== undefined) {
            document.getElementById('maxTemp').value = data.max_temperature;
        }
        if (data.precipitation !== null && data.precipitation !== undefined) {
            document.getElementById('precipitation').value = data.precipitation;
        }
        if (data.snow_thickness !== null && data.snow_thickness !== undefined) {
            document.getElementById('snowThickness').value = data.snow_thickness;
        }
        if (data.precipitation_trace !== null && data.precipitation_trace !== undefined) {
            document.getElementById('precipitationTrace').value = data.precipitation_trace;
        }
        if (data.evaporation !== null && data.evaporation !== undefined) {
            document.getElementById('evaporation').value = data.evaporation;
        }
        if (data.sunshine_duration !== null && data.sunshine_duration !== undefined) {
            document.getElementById('sunshineDuration').value = data.sunshine_duration;
        }
        if (data.sunshine_percentage !== null && data.sunshine_percentage !== undefined) {
            document.getElementById('sunshinePercentage').value = data.sunshine_percentage;
        }
        if (data.max_gust_speed !== null && data.max_gust_speed !== undefined) {
            document.getElementById('maxGustSpeed').value = data.max_gust_speed;
        }
        if (data.max_gust_direction !== null && data.max_gust_direction !== undefined) {
            document.getElementById('maxGustDirection').value = data.max_gust_direction;
        }
        if (data.max_gust_time !== null && data.max_gust_time !== undefined) {
            document.getElementById('maxGustTime').value = data.max_gust_time;
        }
        if (data.max_humidity !== null && data.max_humidity !== undefined) {
            document.getElementById('maxHumidity').value = data.max_humidity;
        }
        if (data.max_humidity_time !== null && data.max_humidity_time !== undefined) {
            document.getElementById('maxHumidityTime').value = data.max_humidity_time;
        }
        if (data.min_humidity !== null && data.min_humidity !== undefined) {
            document.getElementById('minHumidity').value = data.min_humidity;
        }
        if (data.min_humidity_time !== null && data.min_humidity_time !== undefined) {
            document.getElementById('minHumidityTime').value = data.min_humidity_time;
        }
        if (data.observer_notes !== null && data.observer_notes !== undefined) {
            document.getElementById('observerNotes').value = data.observer_notes;
        }
        
        // تعبئة نوع الملخص
        if (data.report_type) {
            const radioButton = document.querySelector(`input[name="reportType"][value="${data.report_type}"]`);
            if (radioButton) {
                radioButton.checked = true;
                if (typeof updateTimezoneInfo === 'function') {
                    updateTimezoneInfo();
                }
                if (typeof updateFieldsVisibility === 'function') {
                    updateFieldsVisibility();
                }
            }
        }
        
        // تعبئة الظواهر الجوية
        if (data.thunderstorm !== null && data.thunderstorm !== undefined) {
            document.getElementById('thunderstorm').checked = data.thunderstorm;
        }
        if (data.hail !== null && data.hail !== undefined) {
            document.getElementById('hail').checked = data.hail;
        }
        if (data.snow_phenomena !== null && data.snow_phenomena !== undefined) {
            document.getElementById('snow').checked = data.snow_phenomena;
        }
        if (data.rain !== null && data.rain !== undefined) {
            document.getElementById('rain').checked = data.rain;
        }
        if (data.frost !== null && data.frost !== undefined) {
            document.getElementById('frost').checked = data.frost;
        }
        if (data.fog !== null && data.fog !== undefined) {
            document.getElementById('fog').checked = data.fog;
        }
        if (data.mist !== null && data.mist !== undefined) {
            document.getElementById('mist').checked = data.mist;
        }
        if (data.dust_storm !== null && data.dust_storm !== undefined) {
            document.getElementById('dustStorm').checked = data.dust_storm;
        }
        if (data.blowing_dust !== null && data.blowing_dust !== undefined) {
            document.getElementById('blowingDust').checked = data.blowing_dust;
        }
        if (data.haze !== null && data.haze !== undefined) {
            document.getElementById('haze').checked = data.haze;
        }
        if (data.stormy_wind !== null && data.stormy_wind !== undefined) {
            document.getElementById('stormyWind').checked = data.stormy_wind;
        }
        
        // تطبيق التنسيق التلقائي
        if (typeof formatFieldOnBlur === 'function') {
            const fieldsToFormat = [
                'minTemp', 'maxTemp', 'precipitation', 'snowThickness',
                'precipitationTrace', 'evaporation', 'sunshineDuration',
                'sunshinePercentage', 'maxGustSpeed', 'maxGustDirection',
                'maxGustTime', 'maxHumidity', 'maxHumidityTime',
                'minHumidity', 'minHumidityTime'
            ];
            
            fieldsToFormat.forEach(fieldId => {
                const field = document.getElementById(fieldId);
                if (field && field.value) {
                    formatFieldOnBlur(field);
                }
            });
        }
        
        if (typeof showNotification === 'function') {
            showNotification('تم تحميل البيانات من JSON بنجاح', 'success');
        }
        
    } catch (error) {
        console.error('خطأ في تعبئة النموذج من JSON:', error);
        if (typeof showNotification === 'function') {
            showNotification('فشل في تحميل البيانات من الملف', 'error');
        }
    }
}

// إنشاء مخطط بيانات للملخص
function createReportChart(formData) {
    // يمكن تطوير هذه الدالة لإنشاء رسوم بيانية
    const chartData = {
        temperatures: {
            min: parseFloat(formData.min_temperature) || 0,
            max: parseFloat(formData.max_temperature) || 0
        },
        humidity: {
            min: parseInt(formData.min_humidity) || 0,
            max: parseInt(formData.max_humidity) || 0
        },
        wind: parseInt(formData.max_gust_speed) || 0
    };
    
    return chartData;
}

// تحويل البيانات إلى صيغة CSV (محدث لدعم القيمة null)
function convertToCSV(formData) {
    const headers = [
        'التاريخ', 'المحطة', 'الراصد', 'نوع الملخص',
        'درجة الحرارة الصغرى', 'درجة الحرارة العظمى',
        'الهطول', 'سماكة الثلج', 'التبخر',
        'مد السطوع', 'النسبة المئوية للسطوع',
        'أكبر نفحة رياح', 'اتجاه الرياح', 'وقت الرياح',
        'أكبر رطوبة', 'وقت أكبر رطوبة', 'أصغر رطوبة', 'وقت أصغر رطوبة'
    ];
    
    const row = [
        formData.display_date || '',
        formData.station || '',
        formData.observer_name || '',
        getReportTypeText(formData.report_type),
        formData.min_temperature !== null ? formData.min_temperature : '#',
        formData.max_temperature !== null ? formData.max_temperature : '#',
        formData.precipitation !== null ? formData.precipitation : '#',
        formData.snow_thickness !== null ? formData.snow_thickness : '#',
        formData.evaporation !== null ? formData.evaporation : '#',
        formData.sunshine_duration !== null ? formData.sunshine_duration : '#',
        formData.sunshine_percentage !== null ? formData.sunshine_percentage : '#',
        formData.max_gust_speed !== null ? formData.max_gust_speed : '#',
        formData.max_gust_direction !== null ? formData.max_gust_direction : '#',
        formData.max_gust_time !== null ? formData.max_gust_time : '#',
        formData.max_humidity !== null ? formData.max_humidity : '#',
        formData.max_humidity_time !== null ? formData.max_humidity_time : '#',
        formData.min_humidity !== null ? formData.min_humidity : '#',
        formData.min_humidity_time !== null ? formData.min_humidity_time : '#'
    ];
    
    const csvContent = [
        headers.join(','),
        row.join(',')
    ].join('\n');
    
    return csvContent;
}

// جعل الدوال متاحة globally
window.exportToJSON = exportToJSON;
window.importFromJSON = importFromJSON;
window.downloadJSON = downloadJSON;
window.uploadJSON = uploadJSON;
window.fillFormFromJSON = fillFormFromJSON;
window.convertToCSV = convertToCSV;

// دالة مساعدة للحصول على نص نوع الملخص
function getReportTypeText(reportType) {
    switch(reportType) {
        case '24h': return 'الملخص اليومي ';
        case '06utc': return 'نشرة 06 توقيت عالمي';
        case '18utc': return 'نشرة 18 توقيت عالمي';
        default: return reportType;
    }
}