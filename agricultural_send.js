// agricultural_send.js - دعم إضافي لإرسال البيانات الزراعية
console.log('📤 تحميل دعم الإرسال الإضافي للنشرات الزراعية...');

// دالة الإرسال الموحدة
async function submitAgriculturalData(formData) {
    try {
        console.log('🚀 بدء عملية إرسال البيانات الزراعية...');
        
        // التحقق من اتصال Supabase
        if (!window.supabaseClient) {
            throw new Error('عميل Supabase غير مهيئ');
        }
        
        // جلب بيانات المستخدم الحالي
        const { data: { user }, error: userError } = await window.supabaseClient.auth.getUser();
        
        if (userError) {
            console.warn('⚠️ خطأ في جلب بيانات المستخدم:', userError);
            showNotification('يجب تسجيل الدخول لإرسال البيانات', 'warning');
            return { success: false, error: userError };
        }
        
        if (!user) {
            throw new Error('يجب تسجيل الدخول أولاً');
        }
        
        // إعداد بيانات التقرير (بالتاريخ الميلادي)
        const reportData = {
            // بيانات المستخدم
            user_id: user.id,
            user_name: formData.user_name || user.email,
            station: formData.user_station || 'غير محدد',
            user_role: formData.user_role || 'راصد جوي',
            user_email: user.email,
            
            // التاريخ (الميلادي)
            report_date: formData.reportDate || new Date().toISOString().split('T')[0],
            submission_date: new Date().toISOString(),
            
            // البيانات المناخية
            avg_air_temp: parseFloat(formData.avgAirTemp) || null,
            max_air_temp: parseFloat(formData.maxAirTemp) || null,
            min_air_temp: parseFloat(formData.minAirTemp) || null,
            min_temp_2m: parseFloat(formData.minTemp2m) || null,
            max_soil_surface_temp: parseFloat(formData.maxSoilSurfaceTemp) || null,
            min_soil_surface_temp: parseFloat(formData.minSoilSurfaceTemp) || null,
            
            avg_humidity: parseInt(formData.avgHumidity) || null,
            min_humidity: parseInt(formData.minHumidity) || null,
            avg_es_e: parseFloat(formData.avgEsE) || null,
            min_es_e: parseFloat(formData.minEsE) || null,
            
            sunshine_hours: parseFloat(formData.sunshineHours) || null,
            total_cloud_cover: parseInt(formData.totalCloudCover) || null,
            low_cloud_cover: parseInt(formData.lowCloudCover) || null,
            
            precipitation: parseFloat(formData.precipitation) || null,
            max_wind_speed: parseInt(formData.maxWindSpeed) || null,
            class_a_evaporation: parseFloat(formData.classAEvaporation) || null,
            avg_wind_speed_2m: parseFloat(formData.avgWindSpeed2m) || null,
            
            avg_soil_temp_5cm: parseFloat(formData.avgSoilTemp5cm) || null,
            avg_soil_temp_10cm: parseFloat(formData.avgSoilTemp10cm) || null,
            avg_soil_temp_20cm: parseFloat(formData.avgSoilTemp20cm) || null,
            avg_soil_temp_50cm: parseFloat(formData.avgSoilTemp50cm) || null,
            field_soil_temp_5cm: parseFloat(formData.fieldSoilTemp5cm) || null,
            field_soil_temp_10cm: parseFloat(formData.fieldSoilTemp10cm) || null,
            log_evaporation: parseFloat(formData.logEvaporation) || null,
            
            dew: formData.dew === '1',
            fog: formData.fog === '1',
            hail: formData.hail === '1',
            sandstorm: formData.sandstorm === '1',
            
            observer_notes: formData.observerNotes || '',
            
            status: 'submitted',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        
        console.log('📦 البيانات المعدة للإرسال:', reportData.report_date);
        
        // إرسال البيانات
        const { data, error } = await window.supabaseClient
            .from('agricultural_reports')
            .insert([reportData])
            .select();
        
        if (error) {
            console.error('❌ خطأ في الإرسال:', error);
            throw error;
        }
        
        console.log('✅ تم إرسال البيانات بنجاح:', data);
        
        return { success: true, data };
        
    } catch (error) {
        console.error('❌ خطأ في عملية الإرسال:', error);
        
        // حفظ البيانات محلياً للاستعادة لاحقاً
        saveLocalBackup(formData, error);
        
        return { success: false, error: error.message };
    }
}

// حفظ نسخة احتياطية محلية
function saveLocalBackup(formData, error) {
    try {
        const backups = JSON.parse(localStorage.getItem('agricultural_backups') || '[]');
        
        backups.push({
            data: formData,
            error: error?.message || 'خطأ غير معروف',
            timestamp: new Date().toISOString(),
            attempt: backups.length + 1
        });
        
        // الاحتفاظ بآخر 50 نسخة احتياطية فقط
        if (backups.length > 50) {
            backups.shift();
        }
        
        localStorage.setItem('agricultural_backups', JSON.stringify(backups));
        console.log('💾 تم حفظ نسخة احتياطية محلية');
        
    } catch (backupError) {
        console.error('❌ فشل حفظ النسخة الاحتياطية:', backupError);
    }
}

// محاولة إعادة إرسال النسخ الاحتياطية
async function retryFailedSubmissions() {
    try {
        const backups = JSON.parse(localStorage.getItem('agricultural_backups') || '[]');
        
        if (backups.length === 0) {
            console.log('📭 لا توجد نسخ احتياطية لإعادة الإرسال');
            return;
        }
        
        console.log(`🔄 محاولة إعادة إرسال ${backups.length} نسخة احتياطية...`);
        
        const successful = [];
        const failed = [];
        
        for (let i = 0; i < backups.length; i++) {
            const backup = backups[i];
            
            try {
                const result = await submitAgriculturalData(backup.data);
                
                if (result.success) {
                    successful.push(backup);
                    console.log(`✅ تمت إعادة إرسال النسخة الاحتياطية ${i + 1}`);
                } else {
                    failed.push(backup);
                    console.warn(`⚠️ فشل إعادة إرسال النسخة الاحتياطية ${i + 1}`);
                }
            } catch (error) {
                failed.push(backup);
                console.error(`❌ خطأ في إعادة إرسال النسخة الاحتياطية ${i + 1}:`, error);
            }
        }
        
        // تحديث قائمة النسخ الاحتياطية
        localStorage.setItem('agricultural_backups', JSON.stringify(failed));
        
        if (successful.length > 0) {
            showNotification(`تمت إعادة إرسال ${successful.length} تقرير بنجاح`, 'success');
        }
        
        return { successful, failed };
        
    } catch (error) {
        console.error('❌ خطأ في عملية إعادة الإرسال:', error);
        return { successful: [], failed: [], error: error.message };
    }
}

// دالة لإنشاء تقرير إحصائي
function generateAgriculturalReport(reports) {
    if (!reports || reports.length === 0) {
        return null;
    }
    
    const stats = {
        totalReports: reports.length,
        stations: {},
        months: {},
        status: {
            submitted: 0,
            draft: 0
        },
        temperatureRange: {
            min: Infinity,
            max: -Infinity,
            avg: 0
        },
        humidityRange: {
            min: Infinity,
            max: -Infinity,
            avg: 0
        }
    };
    
    let tempSum = 0;
    let humiditySum = 0;
    let tempCount = 0;
    let humidityCount = 0;
    
    reports.forEach(report => {
        // إحصاءات المحطات
        const station = report.station || 'غير محدد';
        stats.stations[station] = (stats.stations[station] || 0) + 1;
        
        // إحصاءات الشهور الميلادية
        if (report.report_date) {
            const month = report.report_date.substring(0, 7); // YYYY-MM
            stats.months[month] = (stats.months[month] || 0) + 1;
        }
        
        // إحصاءات الحالة
        stats.status[report.status] = (stats.status[report.status] || 0) + 1;
        
        // إحصاءات درجة الحرارة
        if (report.avg_air_temp !== null) {
            stats.temperatureRange.min = Math.min(stats.temperatureRange.min, report.avg_air_temp);
            stats.temperatureRange.max = Math.max(stats.temperatureRange.max, report.avg_air_temp);
            tempSum += report.avg_air_temp;
            tempCount++;
        }
        
        // إحصاءات الرطوبة
        if (report.avg_humidity !== null) {
            stats.humidityRange.min = Math.min(stats.humidityRange.min, report.avg_humidity);
            stats.humidityRange.max = Math.max(stats.humidityRange.max, report.avg_humidity);
            humiditySum += report.avg_humidity;
            humidityCount++;
        }
    });
    
    // حساب المتوسطات
    if (tempCount > 0) {
        stats.temperatureRange.avg = tempSum / tempCount;
    }
    
    if (humidityCount > 0) {
        stats.humidityRange.avg = humiditySum / humidityCount;
    }
    
    return stats;
}

// جعل الدوال متاحة عالمياً
window.submitAgriculturalData = submitAgriculturalData;
window.retryFailedSubmissions = retryFailedSubmissions;
window.generateAgriculturalReport = generateAgriculturalReport;

console.log('✅ تم تحميل دعم الإرسال الإضافي بنجاح');