// statistics-loader.js - نظام تحميل إحصائيات المحطة
console.log('📊 تحميل نظام إحصائيات المحطة...');

// دالة لجلب إحصائيات المحطة الحالية
async function loadStationStatistics() {
    console.log('📊 جلب إحصائيات المحطة...');
    
    const statsLoading = document.getElementById('statsLoading');
    const statsGrid = document.getElementById('statsGrid');
    
    if (!statsLoading || !statsGrid) {
        console.error('❌ عناصر الإحصائيات غير موجودة');
        return null;
    }
    
    // إظهار حالة التحميل
    statsLoading.style.display = 'block';
    statsGrid.style.display = 'none';
    
    try {
        // الحصول على اسم المحطة من المستخدم الحالي
        const userData = JSON.parse(localStorage.getItem("currentUser") || "{}");
        const userStation = userData.station || "غير محدد";
        
        console.log(`🏢 محطة المستخدم: ${userStation}`);
        
        // التاريخ الحالي
        const today = new Date().toISOString().split('T')[0];
        console.log(`📅 التاريخ الحالي: ${today}`);
        
        // التحقق من وجود اتصال بقاعدة البيانات
        if (typeof supabase === 'undefined') {
            console.warn('⚠️ مكتبة قاعدة البيانات غير متاحة، استخدام بيانات تجريبية');
            
            // استخدام بيانات تجريبية للتطوير
            const demoStats = {
                climate: Math.floor(Math.random() * 5),
                hourly: Math.floor(Math.random() * 10),
                daily: Math.floor(Math.random() * 2),
                rain: Math.floor(Math.random() * 3),
                soil: Math.floor(Math.random() * 4),
                agri: Math.floor(Math.random() * 2)
            };
            
            displayStatistics(demoStats);
            return demoStats;
        }
        
        // تهيئة Supabase
        const SUPABASE_URL = "https://vktcvkwqszehgmhqjrkb.supabase.co";
        const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrdGN2a3dxc3plaGdtaHFqcmtiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxNzE3NTEsImV4cCI6MjA3Nzc0Nzc1MX0.KTX1c8BAJpy1Jp3-IDXFRqb4Jo7SLabiwICBtn_mR5o";
        
        const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        
        // جلب جميع الإحصائيات بشكل متوازي
        console.log('🔄 جلب الإحصائيات من قاعدة البيانات...');
        
        const [
            climateResult,
            hourlyResult,
            dailyResult,
            rainResult,
            soilResult,
            agriResult
        ] = await Promise.all([
            // التقارير المناخية
            supabaseClient
                .from('climate_reports')
                .select('id', { count: 'exact', head: false })
                .eq('station', userStation)
                .eq('report_date', today),
            
            // التقارير الساعية
            supabaseClient
                .from('hourly_reports')
                .select('id', { count: 'exact', head: false })
                .eq('station_name', userStation)
                .gte('submission_date', today + 'T00:00:00')
                .lte('submission_date', today + 'T23:59:59'),
            
            // التقارير اليومية
            supabaseClient
                .from('daily_reports')
                .select('id', { count: 'exact', head: false })
                .eq('station', userStation)
                .eq('report_date', today),
            
            // التقارير المطرية
            supabaseClient
                .from('rainfall_reports')
                .select('id', { count: 'exact', head: false })
                .eq('observer_station', userStation)
                .gte('observation_date', today + 'T00:00:00')
                .lte('observation_date', today + 'T23:59:59'),
            
            // حرارة التربة
            supabaseClient
                .from('soil_temperatures')
                .select('id', { count: 'exact', head: false })
                .eq('station', userStation)
                .gte('observation_date', today + 'T00:00:00')
                .lte('observation_date', today + 'T23:59:59'),
            
            // التقارير الزراعية
            supabaseClient
                .from('agricultural_reports')
                .select('id', { count: 'exact', head: false })
                .eq('station', userStation)
                .eq('report_date', today)
        ]);

        // معالجة النتائج
        const stats = {
            climate: climateResult?.count || 0,
            hourly: hourlyResult?.count || 0,
            daily: dailyResult?.count || 0,
            rain: rainResult?.count || 0,
            soil: soilResult?.count || 0,
            agri: agriResult?.count || 0
        };

        console.log('✅ الإحصائيات المسترجعة:', stats);
        
        // عرض النتائج في الواجهة
        displayStatistics(stats);
        
        // إخفاء شاشة التحميل
        if (statsLoading) statsLoading.style.display = 'none';
        if (statsGrid) {
            statsGrid.style.display = 'grid';
            statsGrid.style.opacity = '1';
        }
        
        return stats;
        
    } catch (error) {
        console.error('❌ خطأ في جلب الإحصائيات:', error);
        
        // إظهار رسالة خطأ
        if (statsLoading) {
            statsLoading.innerHTML = `
                <div class="text-light">
                    <i class="fas fa-exclamation-triangle me-2"></i>
                    تعذر تحديث الإحصائيات
                    <br>
                    <small>${error.message}</small>
                </div>
            `;
        }
        
        // عرض بيانات تجريبية في حالة الخطأ
        const fallbackStats = {
            climate: 0,
            hourly: 0,
            daily: 0,
            rain: 0,
            soil: 0,
            agri: 0
        };
        
        displayStatistics(fallbackStats);
        
        return null;
    }
}

// دالة لعرض الإحصائيات
function displayStatistics(stats) {
    const statsGrid = document.getElementById('statsGrid');
    if (!statsGrid) return;
    
    const statsData = [
        { 
            id: 'climate', 
            name: 'التقارير المناخية', 
            count: stats.climate || 0, 
            icon: 'fa-wind', 
            description: 'الساعي المناخي' 
        },
        { 
            id: 'hourly', 
            name: 'التقارير الساعية', 
            count: stats.hourly || 0, 
            icon: 'fa-clock', 
            description: 'نشرات ساعية' 
        },
        { 
            id: 'daily', 
            name: 'التقارير اليومية', 
            count: stats.daily || 0, 
            icon: 'fa-calendar-day', 
            description: 'نشرات يومية' 
        },
        { 
            id: 'rain', 
            name: 'التقارير المطرية', 
            count: stats.rain || 0, 
            icon: 'fa-cloud-rain', 
            description: 'الأمطار' 
        },
        { 
            id: 'soil', 
            name: 'حرارة التربة', 
            count: stats.soil || 0, 
            icon: 'fa-thermometer-half', 
            description: 'حرارة التربة' 
        },
        { 
            id: 'agri', 
            name: 'التقارير الزراعية', 
            count: stats.agri || 0, 
            icon: 'fa-leaf', 
            description: 'النشرات الزراعية' 
        }
    ];
    
    let html = '';
    
    statsData.forEach(stat => {
        // تحديد حالة العنصر بناءً على العدد
        let statusClass = 'complete';
        let statusIcon = '✓';
        
        if (stat.count === 0) {
            statusClass = 'danger';
            statusIcon = '✗';
        } else if (stat.count < 3) {
            statusClass = 'warning';
            statusIcon = '⚠';
        }
        
        html += `
            <div class="stat-item ${statusClass}">
                <div class="stat-icon">
                    <i class="fas ${stat.icon}"></i>
                </div>
                <div class="stat-content">
                    <div class="stat-count">
                        ${stat.count}
                    </div>
                    <div class="stat-name">
                        ${stat.name}
                    </div>
                    <div class="stat-desc">
                        ${stat.description}
                    </div>
                </div>
                <div class="stat-status">
                    ${statusIcon}
                </div>
            </div>
        `;
    });
    
    statsGrid.innerHTML = html;
}

// تحديث الإحصائيات بشكل دوري
function setupStatisticsRefresh() {
    // تحديث أولي عند التحميل
    setTimeout(() => {
        loadStationStatistics();
    }, 2000);
    
    // تحديث كل 2 دقيقة
    setInterval(() => {
        loadStationStatistics();
    }, 120000);
}

// تهيئة النظام عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
    console.log('🔧 تهيئة نظام الإحصائيات...');
    
    // الانتظار لتحميل بيانات المستخدم أولاً
    setTimeout(() => {
        setupStatisticsRefresh();
        
        // إضافة أنماط CSS للإحصائيات
        addStatisticsStyles();
        
        console.log('✅ تم تهيئة نظام الإحصائيات');
    }, 1000);
});

// إضافة أنماط CSS مخصصة
function addStatisticsStyles() {
    if (document.getElementById('statistics-styles')) return;
    
    const styles = `
        /* تنسيق صندوق الإحصائيات */
        .station-stats {
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            color: white;
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 20px;
            box-shadow: 0 3px 10px rgba(0,0,0,0.1);
            border: 1px solid rgba(255,255,255,0.05);
        }
        
        .station-stats h5 {
            color: white;
            margin-bottom: 15px;
            font-size: 1.1rem;
        }
        
        /* تنسيق شبكة العناصر */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 12px;
            margin-top: 10px;
        }
        
        /* تنسيق العنصر الفردي داخل الإحصائيات */
        .stat-item {
            background: rgba(255,255,255,0.08);
            border-radius: 8px;
            padding: 12px;
            text-align: center;
            transition: all 0.3s ease;
            border: 1px solid rgba(255,255,255,0.05);
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 100px;
            position: relative;
        }
        
        .stat-item:hover {
            transform: translateY(-3px);
            background: rgba(255,255,255,0.12);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        
        /* ألوان الحالات المختلفة */
        .stat-item.complete { 
            border-left: 4px solid #2ecc71;
        }
        
        .stat-item.warning { 
            border-left: 4px solid #f1c40f;
        }
        
        .stat-item.danger { 
            border-left: 4px solid #e74c3c;
        }
        
        .stat-icon {
            font-size: 1.5rem;
            margin-bottom: 10px;
            color: rgba(255,255,255,0.8);
        }
        
        .stat-content {
            flex: 1;
        }
        
        .stat-count {
            font-size: 1.8rem;
            font-weight: bold;
            display: block;
            margin-bottom: 5px;
        }
        
        .stat-name {
            font-size: 0.9rem;
            margin-bottom: 3px;
            font-weight: 500;
        }
        
        .stat-desc {
            font-size: 0.75rem;
            opacity: 0.8;
        }
        
        .stat-status {
            position: absolute;
            top: 8px;
            right: 8px;
            font-size: 0.8rem;
            font-weight: bold;
        }
        
        .stat-item.complete .stat-status { color: #2ecc71; }
        .stat-item.warning .stat-status { color: #f1c40f; }
        .stat-item.danger .stat-status { color: #e74c3c; }
        
        /* شاشة التحميل */
        .stats-loading {
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            color: rgba(255,255,255,0.8);
        }
        
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        .stat-item {
            animation: fadeIn 0.5s ease forwards;
        }
        
        .stat-item:nth-child(1) { animation-delay: 0.1s; }
        .stat-item:nth-child(2) { animation-delay: 0.2s; }
        .stat-item:nth-child(3) { animation-delay: 0.3s; }
        .stat-item:nth-child(4) { animation-delay: 0.4s; }
        .stat-item:nth-child(5) { animation-delay: 0.5s; }
        .stat-item:nth-child(6) { animation-delay: 0.6s; }
    `;
    
    const styleElement = document.createElement('style');
    styleElement.id = 'statistics-styles';
    styleElement.textContent = styles;
    document.head.appendChild(styleElement);
}

// جعل الدوال متاحة عالمياً للاستخدام
window.loadStationStatistics = loadStationStatistics;
window.displayStatistics = displayStatistics;
window.setupStatisticsRefresh = setupStatisticsRefresh;

console.log('📊 تم تحميل نظام إحصائيات المحطة');