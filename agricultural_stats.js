// agricultural_stats.js - إدارة إحصائيات المحطة للتقارير الزراعية

// الدالة الرئيسية لجلب إحصائيات المحطة
async function loadStationStatistics() {
    const statsLoading = document.getElementById('statsLoading');
    const statsGrid = document.getElementById('statsGrid');
    
    if (!statsLoading || !statsGrid) {
        console.error('❌ عناصر الإحصائيات غير موجودة في الصفحة');
        return;
    }

    try {
        // إظهار علامة التحميل
        statsLoading.style.display = 'flex';
        statsGrid.style.display = 'none';

        // الحصول على اسم المحطة
        const userStationElement = document.getElementById('userStation');
        if (!userStationElement) {
            throw new Error('عنصر اسم المحطة غير موجود');
        }
        
        const userStation = userStationElement.textContent || 'غير محدد';
        
        console.log('📊 جلب إحصائيات مفصلة للمحطة:', userStation);

        // التحقق من وجود اتصال supabase
        const supabase = window.supabaseClient;
        if (!supabase) {
            throw new Error('الاتصال بقاعدة البيانات غير متوفر');
        }

        // الحصول على التاريخ الحالي
        const now = new Date();
        const todayDate = now.toISOString().split('T')[0];
        const tomorrowDate = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString().split('T')[0];

        console.log('📅 نطاق التاريخ:', { today: todayDate, tomorrow: tomorrowDate });

        // جلب البيانات بشكل متوازي لسرعة الأداء
        const [
            agricultural, hourly, daily, rain, climate, soil
        ] = await Promise.all([
            // 1. التقارير الزراعية
            supabase.from('agricultural_reports')
                .select('*', { count: 'exact', head: true })
                .eq('station', userStation)
                .gte('created_at', `${todayDate}T00:00:00.000Z`)
                .lt('created_at', `${tomorrowDate}T00:00:00.000Z`),
            
            // 2. التقارير الساعية
            supabase.from('hourly_reports')
                .select('*', { count: 'exact', head: true })
                .eq('station_name', userStation)
                .gte('created_at', `${todayDate}T00:00:00.000Z`)
                .lt('created_at', `${tomorrowDate}T00:00:00.000Z`),
            
            // 3. التقارير اليومية
            supabase.from('daily_reports')
                .select('*', { count: 'exact', head: true })
                .eq('station', userStation)
                .gte('report_date', todayDate)
                .lt('report_date', tomorrowDate),
            
            // 4. تقارير المطر
            supabase.from('rainfall_reports')
                .select('*', { count: 'exact', head: true })
                .eq('observer_station', userStation)
                .gte('observation_date', todayDate)
                .lt('observation_date', tomorrowDate),
            
            // 5. التقارير المناخية
            supabase.from('climate_reports')
                .select('*', { count: 'exact', head: true })
                .eq('user_station', userStation)
                .gte('report_date', todayDate)
                .lt('report_date', tomorrowDate),
            
            // 6. تقارير التربة
            supabase.from('soil_temperatures')
                .select('*', { count: 'exact', head: true })
                .eq('station', userStation)
                .gte('observation_date', todayDate)
                .lt('observation_date', tomorrowDate)
        ]);

        // جمع النتائج
        const actualCounts = {
            agricultural: agricultural.count || 0,
            hourly: hourly.count || 0,
            daily: daily.count || 0,
            rain: rain.count || 0,
            climate: climate.count || 0,
            soil: soil.count || 0
        };

        // القيم المتوقعة لكل نوع تقرير
        const expectedCounts = {
            hourly: 24,      // 24 تقرير ساعي
            daily: 3,        // 3 تقارير يومية
            rain: 1,         // 1 تقرير مطر
            agricultural: 1, // 1 تقرير زراعي
            soil: 4,         // 4 تقارير تربة
            climate: 4       // 4 تقارير مناخية
        };

        // حساب الإجمالي
        const totalExpected = Object.values(expectedCounts).reduce((a, b) => a + b, 0);
        const totalActual = Object.values(actualCounts).reduce((a, b) => a + b, 0);
        const totalMissing = Math.max(0, totalExpected - totalActual);

        console.log('📈 الإحصائيات الزراعية:', {
            expected: expectedCounts,
            actual: actualCounts,
            totals: { expected: totalExpected, actual: totalActual, missing: totalMissing }
        });

        // تحديث واجهة الإحصائيات
        updateStatsInterface(actualCounts, expectedCounts, totalActual, totalExpected, totalMissing, userStation);

        // إخفاء التحميل وإظهار النتائج
        statsLoading.style.display = 'none';
        statsGrid.style.display = 'grid';

        console.log('✅ تم تحديث إحصائيات المحطة الزراعية بنجاح');

    } catch (error) {
        console.error('❌ خطأ في جلب إحصائيات المحطة:', error);
        showStatsError(error.message);
    }
}

// تحديث واجهة الإحصائيات
function updateStatsInterface(actualCounts, expectedCounts, totalActual, totalExpected, totalMissing, stationName) {
    // تحديث العناصر الأساسية
    const totalElement = document.getElementById('totalReportsCount');
    const todayElement = document.getElementById('todayReportsCount');
    const missingElement = document.getElementById('missingReportsCount');
    
    if (totalElement) totalElement.textContent = totalActual;
    if (todayElement) todayElement.textContent = totalExpected;
    if (missingElement) missingElement.textContent = totalMissing;

    // تحديث عنوان المحطة
    const stationTitle = document.querySelector('.station-stats h5');
    if (stationTitle && stationName) {
        stationTitle.innerHTML = `
            <i class="fas fa-chart-pie me-2"></i>
            إحصائيات محطة ${stationName} - اليوم
        `;
    }

    // إضافة العناصر التفصيلية
    const statsGrid = document.getElementById('statsGrid');
    
    // تنظيف العناصر الموجودة (باستثناء العناصر الأساسية)
    const basicItems = ['statTotal', 'statToday', 'statMissing'];
    Array.from(statsGrid.children).forEach(child => {
        if (!basicItems.includes(child.id)) {
            child.remove();
        }
    });

    // إضافة العناصر التفصيلية
    const detailedItems = [
        {
            id: 'statHourly',
            label: 'الساعية',
            actual: actualCounts.hourly,
            expected: expectedCounts.hourly,
            type: 'hourly',
            icon: 'fas fa-clock'
        },
        {
            id: 'statDaily',
            label: 'اليومية',
            actual: actualCounts.daily,
            expected: expectedCounts.daily,
            type: 'daily',
            icon: 'fas fa-calendar-day'
        },
        {
            id: 'statRain',
            label: 'المطرية',
            actual: actualCounts.rain,
            expected: expectedCounts.rain,
            type: 'rain',
            icon: 'fas fa-cloud-rain'
        },
        {
            id: 'statAgricultural',
            label: 'الزراعية',
            actual: actualCounts.agricultural,
            expected: expectedCounts.agricultural,
            type: 'agricultural',
            icon: 'fas fa-leaf'
        },
        {
            id: 'statSoil',
            label: 'التربة',
            actual: actualCounts.soil,
            expected: expectedCounts.soil,
            type: 'soil',
            icon: 'fas fa-temperature-half'
        },
        {
            id: 'statClimate',
            label: 'المناخية',
            actual: actualCounts.climate,
            expected: expectedCounts.climate,
            type: 'climate',
            icon: 'fas fa-wind'
        }
    ];

    detailedItems.forEach(item => {
        // إنشاء عنصر جديد
        const statItem = document.createElement('div');
        statItem.className = 'stat-item';
        statItem.id = item.id;
        
        // حساب النسبة المئوية
        const percentage = item.expected > 0 ? Math.round((item.actual / item.expected) * 100) : 0;
        
        // تحديد حالة العنصر بناءً على النسبة
        if (item.actual >= item.expected) {
            statItem.classList.add('complete');
        } else if (item.actual > 0) {
            statItem.classList.add('warning');
        } else {
            statItem.classList.add('danger');
        }
        
        // HTML العنصر
        statItem.innerHTML = `
            <div class="stat-icon">
                <i class="${item.icon}"></i>
            </div>
            <div class="stat-label">${item.label} (${item.actual}/${item.expected})</div>
            <div class="stat-count">${percentage}%</div>
        `;
        
        // إضافة مستمع حدث للتفاصيل
        statItem.addEventListener('click', () => {
            showReportDetails(item.type, item.label, item.actual, item.expected);
        });
        
        // إضافة المؤشر على المؤشر
        statItem.style.cursor = 'pointer';
        statItem.title = `انقر لعرض تفاصيل ${item.label}`;
        
        // إضافة العنصر قبل العنصر الأخير (ناقصة)
        const missingItem = document.getElementById('statMissing');
        if (missingItem && missingItem.parentNode) {
            statsGrid.insertBefore(statItem, missingItem);
        }
    });

    // تحديث ألوان الحالات الأساسية
    const statTotal = document.getElementById('statTotal');
    const statToday = document.getElementById('statToday');
    const statMissing = document.getElementById('statMissing');
    
    if (statToday) {
        if (totalActual >= totalExpected) {
            statToday.className = 'stat-item complete';
        } else if (totalActual > 0) {
            statToday.className = 'stat-item warning';
        } else {
            statToday.className = 'stat-item danger';
        }
    }
    
    if (statMissing) {
        if (totalMissing === 0) {
            statMissing.className = 'stat-item complete';
        } else if (totalMissing < totalExpected) {
            statMissing.className = 'stat-item warning';
        } else {
            statMissing.className = 'stat-item danger';
        }
    }
}

// إظهار تفاصيل التقارير
function showReportDetails(reportType, reportLabel, actualCount, expectedCount) {
    const userStation = document.getElementById('userStation').textContent;
    const today = new Date().toISOString().split('T')[0];
    
    let details = '';
    
    switch(reportType) {
        case 'hourly':
            details = `التقارير الساعية: ${actualCount} من ${expectedCount} (مطلوب 24 تقرير ساعي يومياً)`;
            break;
        case 'daily':
            details = `التقارير اليومية: ${actualCount} من ${expectedCount} (24h, 06utc, 18utc)`;
            break;
        case 'rain':
            details = `تقرير المطر: ${actualCount} من ${expectedCount} (تقرير واحد يومياً)`;
            break;
        case 'agricultural':
            details = `التقرير الزراعي: ${actualCount} من ${expectedCount} (تقرير واحد يومياً)`;
            break;
        case 'soil':
            details = `تقارير التربة: ${actualCount} من ${expectedCount} (مطلوب 4 تقارير: 02, 08, 14, 20)`;
            break;
        case 'climate':
            details = `التقارير المناخية: ${actualCount} من ${expectedCount} (مطلوب 4 تقارير يومياً)`;
            break;
    }
    
    const message = `
        <div class="alert alert-info alert-dismissible fade show" role="alert">
            <h6><i class="fas fa-info-circle"></i> تفاصيل ${reportLabel}</h6>
            <p>${details}</p>
            <p><strong>المحطة:</strong> ${userStation}</p>
            <p><strong>التاريخ:</strong> ${today}</p>
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        </div>
    `;
    
    // إظهار التنبيه
    const notificationContainer = document.getElementById('notificationContainer') || document.body;
    const alertDiv = document.createElement('div');
    alertDiv.innerHTML = message;
    notificationContainer.appendChild(alertDiv);
    
    // إزالة التنبيه بعد 5 ثوان
    setTimeout(() => {
        if (alertDiv.parentNode) {
            alertDiv.parentNode.removeChild(alertDiv);
        }
    }, 5000);
}

// عرض رسالة خطأ
function showStatsError(errorMessage) {
    const statsLoading = document.getElementById('statsLoading');
    const statsGrid = document.getElementById('statsGrid');
    
    if (statsLoading) {
        statsLoading.innerHTML = `
            <div class="text-center text-danger">
                <i class="fas fa-exclamation-triangle me-2"></i>
                تعذر تحديث الإحصائيات
                <br>
                <small class="opacity-75">${errorMessage || 'تأكد من اتصالك بالإنترنت'}</small>
                <br>
                <button class="btn btn-sm btn-outline-light mt-3" onclick="loadStationStatistics()">
                    <i class="fas fa-redo me-1"></i>إعادة المحاولة
                </button>
            </div>
        `;
        statsLoading.style.display = 'flex';
    }
    
    if (statsGrid) {
        statsGrid.style.display = 'none';
    }
}

// إعداد التحديث التلقائي للإحصائيات
function setupAutoRefreshStats(intervalMinutes = 5) {
    // تحديث الإحصائيات فور تحميل الصفحة
    setTimeout(loadStationStatistics, 1000);
    
    // تحديث كل X دقائق
    setInterval(() => {
        console.log(`🔄 تحديث تلقائي للإحصائيات الزراعية (كل ${intervalMinutes} دقائق)`);
        loadStationStatistics();
    }, intervalMinutes * 60 * 1000);
}

// تهيئة الإحصائيات عند تحميل الصفحة
function initAgriculturalStats() {
    document.addEventListener('DOMContentLoaded', function() {
        // انتظر حتى يتم تحميل Supabase
        const checkSupabase = setInterval(() => {
            if (window.supabaseClient) {
                clearInterval(checkSupabase);
                console.log('📊 تهيئة نظام الإحصائيات الزراعية...');
                
                // بدء تحميل الإحصائيات
                loadStationStatistics();
                
                // إعداد التحديث التلقائي
                setupAutoRefreshStats(5);
                
                // تحديث الإحصائيات عند تغيير التاريخ
                const dateField = document.getElementById('reportDate');
                if (dateField) {
                    dateField.addEventListener('change', loadStationStatistics);
                }
                
                // تحديث الإحصائيات عند إرسال تقرير جديد
                const form = document.getElementById('agriculturalReportForm');
                if (form) {
                    form.addEventListener('submit', function() {
                        // تحديث الإحصائيات بعد 3 ثوانٍ من الإرسال
                        setTimeout(loadStationStatistics, 3000);
                    });
                }
            }
        }, 500);
    });
}

// جعل الدوال متاحة globally
window.loadStationStatistics = loadStationStatistics;
window.setupAutoRefreshStats = setupAutoRefreshStats;
window.initAgriculturalStats = initAgriculturalStats;
window.showReportDetails = showReportDetails;

// تشغيل تهيئة الإحصائيات
initAgriculturalStats();