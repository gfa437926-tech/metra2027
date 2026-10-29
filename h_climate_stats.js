// h_climate_stats.js - إدارة إحصائيات المحطة للمناخ الساعي (معدل - بدون توقيت محلي)

// دالة للحصول على عميل Supabase
function getSupabaseClient() {
    if (typeof supabase === 'undefined') {
        console.error('❌ مكتبة Supabase غير محملة');
        return null;
    }
    
    const SUPABASE_URL = "https://vktcvkwqszehgmhqjrkb.supabase.co";
    const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrdGN2a3dxc3plaGdtaHFqcmtiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxNzE3NTEsImV4cCI6MjA3Nzc0Nzc1MX0.KTX1c8BAJpy1Jp3-IDXFRqb4Jo7SLabiwICBtn_mR5o";
    
    return supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

// جلب إحصائيات المحطة بشكل مفصل
async function loadStationStatistics() {
    const statsLoading = document.getElementById('statsLoading');
    const statsGrid = document.getElementById('statsGrid');
    
    if (!statsLoading || !statsGrid) {
        console.error('❌ عناصر الإحصائيات غير موجودة في الصفحة');
        return;
    }

    try {
        // إظهار علامة التحميل
        statsLoading.style.display = 'block';
        statsGrid.style.display = 'none';

        // الحصول على اسم المحطة من الواجهة
        const userStationElement = document.getElementById('userStation');
        if (!userStationElement) {
            throw new Error('عنصر اسم المحطة غير موجود');
        }
        
        const userStation = userStationElement.textContent || 'غير محدد';
        
        console.log('📊 جلب إحصائيات مفصلة للمحطة (UTC فقط):', userStation);

        // التحقق من وجود اتصال supabase
        const supabase = getSupabaseClient();
        if (!supabase) {
            throw new Error('الاتصال بقاعدة البيانات غير متوفر');
        }

        // الحصول على التاريخ الحالي (من 00:00 توقيت عالمي)
        const now = new Date();
        const todayDate = now.toISOString().split('T')[0];
        
        // حساب بداية اليوم ونهاية اليوم بالتوقيت العالمي
        const startOfDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
        const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);

        console.log('📅 نطاق التاريخ (UTC):', { 
            today: todayDate, 
            start: startOfDay.toISOString(), 
            end: endOfDay.toISOString() 
        });

        // جلب جميع التقارير دفعة واحدة باستخدام Promise.all
        const [hourlyRes, dailyRes, rainRes, agriRes, soilRes, climateRes] = await Promise.all([
            // 1. التقارير الساعية
            supabase
                .from('hourly_reports')
                .select('*', { count: 'exact', head: true })
                .eq('station_name', userStation)
                .gte('created_at', startOfDay.toISOString())
                .lt('created_at', endOfDay.toISOString()),
            
            // 2. التقارير اليومية
            supabase
                .from('daily_reports')
                .select('*', { count: 'exact', head: true })
                .eq('station', userStation)
                .gte('submission_timestamp', startOfDay.toISOString())
                .lt('submission_timestamp', endOfDay.toISOString()),
            
            // 3. تقارير المطر
            supabase
                .from('rainfall_reports')
                .select('*', { count: 'exact', head: true })
                .eq('station_name', userStation)
                .gte('observation_date', todayDate),
            
            // 4. التقارير الزراعية
            supabase
                .from('agricultural_reports')
                .select('*', { count: 'exact', head: true })
                .eq('station', userStation)
                .eq('report_date', todayDate),
            
            // 5. تقارير التربة
            supabase
                .from('soil_temperatures')
                .select('*', { count: 'exact', head: true })
                .eq('station', userStation)
                .eq('observation_date', todayDate),
            
            // 6. التقارير المناخية (UTC فقط)
            supabase
                .from('climate_reports')
                .select('*', { count: 'exact', head: true })
                .eq('user_station', userStation)
                .eq('report_date', todayDate)
        ]);

        // التحقق من الأخطاء
        const errors = [];
        if (hourlyRes.error) errors.push(`التقارير الساعية: ${hourlyRes.error.message}`);
        if (dailyRes.error) errors.push(`التقارير اليومية: ${dailyRes.error.message}`);
        if (rainRes.error) errors.push(`تقارير المطر: ${rainRes.error.message}`);
        if (agriRes.error) errors.push(`التقارير الزراعية: ${agriRes.error.message}`);
        if (soilRes.error) errors.push(`تقارير التربة: ${soilRes.error.message}`);
        if (climateRes.error) errors.push(`التقارير المناخية: ${climateRes.error.message}`);
        
        if (errors.length > 0) {
            throw new Error(errors.join(' | '));
        }

        // حساب الإحصائيات
        const actualCounts = {
            hourly: hourlyRes.count || 0,
            daily: dailyRes.count || 0,
            rain: rainRes.count || 0,
            agricultural: agriRes.count || 0,
            soil: soilRes.count || 0,
            climate: climateRes.count || 0
        };

        const expectedCounts = {
            hourly: 24,      // 24 تقرير ساعي
            daily: 3,        // 3 تقارير يومية
            rain: 1,         // 1 تقرير مطر
            agricultural: 1, // 1 تقرير زراعي
            soil: 4,         // 4 تقارير تربة
            climate: 4       // 4 تقارير مناخية
        };

        // حساب الإجماليات
        const totalExpected = Object.values(expectedCounts).reduce((a, b) => a + b, 0);
        const totalActual = Object.values(actualCounts).reduce((a, b) => a + b, 0);
        const totalMissing = Math.max(0, totalExpected - totalActual);

        console.log('📈 الإحصائيات المفصلة (UTC فقط):', {
            actual: actualCounts,
            expected: expectedCounts,
            totals: { expected: totalExpected, actual: totalActual, missing: totalMissing }
        });

        // تحديث الواجهة
        updateStatsInterface(actualCounts, expectedCounts, totalActual, totalExpected, totalMissing);

        // إخفاء التحميل وإظهار النتائج
        statsLoading.style.display = 'none';
        statsGrid.style.display = 'grid';

        console.log('✅ تم تحديث إحصائيات المحطة بنجاح (UTC فقط)');

    } catch (error) {
        console.error('❌ خطأ في جلب إحصائيات المحطة:', error);
        
        // إظهار رسالة الخطأ
        if (statsLoading) {
            statsLoading.innerHTML = `
                <div class="text-light">
                    <i class="fas fa-exclamation-triangle me-2"></i>
                    تعذر تحديث الإحصائيات: ${error.message || 'خطأ غير معروف'}
                </div>
            `;
        }
        
        // إظهار الشبكة فارغة في حالة الخطأ
        if (statsGrid) {
            statsGrid.style.display = 'grid';
            statsGrid.innerHTML = `
                <div class="stat-item danger">
                    <div class="stat-label">خطأ في التحميل (UTC)</div>
                    <span class="stat-count">0</span>
                </div>
            `;
        }
    }
}

// دالة مساعدة لتحديث الواجهة
function updateStatsInterface(actualCounts, expectedCounts, totalActual, totalExpected, totalMissing) {
    const statsGrid = document.getElementById('statsGrid');
    
    if (!statsGrid) return;
    
    // تنظيف المحتوى السابق
    statsGrid.innerHTML = '';
    
    // إضافة عنصر خاص للمناخ الساعي (UTC فقط)
    const utcInfoItem = document.createElement('div');
    utcInfoItem.className = 'stat-item complete';
    utcInfoItem.innerHTML = `
        <div class="stat-label">المناخ الساعي (UTC)</div>
        <span class="stat-count">${actualCounts.climate || 0}</span>
        <small class="stat-desc">يستخدم UTC فقط</small>
    `;
    statsGrid.appendChild(utcInfoItem);
    
    // إنشاء العناصر الإحصائية
    const statsItems = [
        {
            id: 'statTotal',
            label: 'إجمالي التقارير',
            count: totalActual,
            type: 'total',
            expected: totalExpected,
            actual: totalActual
        },
        {
            id: 'statToday',
            label: 'مطلوب اليوم',
            count: totalExpected,
            type: 'today',
            expected: totalExpected,
            actual: totalActual
        },
        {
            id: 'statMissing',
            label: 'ناقصة',
            count: totalMissing,
            type: 'missing',
            expected: totalExpected,
            actual: totalActual
        }
    ];
    
    // إضافة الإحصائيات التفصيلية
    const detailedStats = [
        { key: 'hourly', label: 'الساعية' },
        { key: 'daily', label: 'اليومية' },
        { key: 'rain', label: 'المطرية' },
        { key: 'agricultural', label: 'الزراعية' },
        { key: 'soil', label: 'التربة' }
    ];
    
    detailedStats.forEach(item => {
        const actual = actualCounts[item.key] || 0;
        const expected = expectedCounts[item.key] || 0;
        const percentage = expected > 0 ? Math.round((actual / expected) * 100) : 0;
        
        statsItems.push({
            id: `stat${item.key.charAt(0).toUpperCase() + item.key.slice(1)}`,
            label: `${item.label} (${actual}/${expected})`,
            count: `${percentage}%`,
            type: item.key,
            expected: expected,
            actual: actual
        });
    });
    
    // إضافة العناصر إلى الشبكة
    statsItems.forEach(item => {
        const statElement = createStatElement(item);
        statsGrid.appendChild(statElement);
    });
}

// إنشاء عنصر إحصائي
function createStatElement(data) {
    const statItem = document.createElement('div');
    statItem.className = 'stat-item';
    statItem.id = data.id;
    
    // تحديد الفئة بناءً على النسبة
    let itemClass = 'danger';
    if (data.type === 'total' || data.type === 'today') {
        itemClass = 'complete';
    } else if (data.type === 'missing') {
        if (data.count === 0) itemClass = 'complete';
        else if (data.count < 5) itemClass = 'warning';
    } else {
        const percentage = data.expected > 0 ? (data.actual / data.expected) * 100 : 0;
        if (percentage >= 100) itemClass = 'complete';
        else if (percentage >= 50) itemClass = 'warning';
    }
    
    statItem.classList.add(itemClass);
    
    // إنشاء المحتوى
    const label = document.createElement('div');
    label.className = 'stat-label';
    label.textContent = data.label;
    
    const count = document.createElement('span');
    count.className = 'stat-count';
    count.textContent = data.count;
    
    if (data.actual !== undefined && data.expected !== undefined) {
        count.title = `${data.actual} من ${data.expected}`;
    }
    
    // إضافة المستمعين
    statItem.addEventListener('click', () => {
        showStatDetails(data);
    });
    
    statItem.appendChild(label);
    statItem.appendChild(count);
    
    return statItem;
}

// إظهار تفاصيل الإحصائية
function showStatDetails(data) {
    const userStation = document.getElementById('userStation')?.textContent || 'غير محدد';
    const today = new Date().toISOString().split('T')[0];
    
    let message = '';
    switch(data.type) {
        case 'total':
            message = `إجمالي التقارير المسجلة اليوم: ${data.actual} تقرير`;
            break;
        case 'today':
            message = `إجمالي التقارير المطلوبة اليوم: ${data.expected} تقرير`;
            break;
        case 'missing':
            message = `التقارير الناقصة اليوم: ${data.count} تقرير`;
            break;
        default:
            message = `تقارير ${getArabicType(data.type)}: ${data.actual} من ${data.expected} (${data.count})`;
    }
    
    alert(`📊 تفاصيل الإحصائية (UTC)\n\n${message}\nالمحطة: ${userStation}\nالتاريخ: ${today}\n\nملاحظة: يتم استخدام التوقيت العالمي (UTC) فقط`);
}

// دالة مساعدة للحصول على الاسم العربي
function getArabicType(type) {
    const types = {
        'hourly': 'الساعية',
        'daily': 'اليومية',
        'rain': 'المطرية',
        'agricultural': 'الزراعية',
        'soil': 'التربة',
        'climate': 'المناخية'
    };
    
    return types[type] || type;
}

// التهيئة
function initStats() {
    // انتظر حتى يتم تحميل الصفحة بالكامل
    setTimeout(() => {
        console.log('📊 تهيئة نظام الإحصائيات للمناخ الساعي (UTC فقط)...');
        
        // تحميل الإحصائيات مباشرة
        loadStationStatistics();
        
        // تحديث الإحصائيات كل 5 دقائق
        setInterval(() => {
            console.log('🔄 تحديث تلقائي للإحصائيات (UTC)...');
            loadStationStatistics();
        }, 5 * 60 * 1000);
        
        // تحديث الإحصائيات عند إرسال تقرير جديد
        document.addEventListener('reportSubmitted', function() {
            setTimeout(loadStationStatistics, 2000);
        });
        
    }, 1500);
}

// جعل الدوال متاحة globally
window.loadStationStatistics = loadStationStatistics;
window.initStats = initStats;

// تشغيل التهيئة عند تحميل الصفحة
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initStats);
} else {
    initStats();
}

console.log('📊 تم تحميل نظام الإحصائيات للمناخ الساعي (UTC فقط)');