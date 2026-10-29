// station-stats.js
document.addEventListener('DOMContentLoaded', function() {
    // تهيئة نظام الإحصائيات
    window.initStatsSystem = function() {
        console.log('تهيئة نظام الإحصائيات...');
        
        // تحديث الإحصائيات فور التحميل
        updateStationStats();
        
        // تحديث الإحصائيات كل 5 دقائق
        setInterval(updateStationStats, 5 * 60 * 1000);
        
        // تحديث تاريخ اليوم
        updateCurrentDate();
        
        // إضافة معالج حدث للتحديث اليدوي
        document.addEventListener('stats:refresh', updateStationStats);
    };

    // تحديث تاريخ اليوم
    function updateCurrentDate() {
        const today = new Date();
        const options = { 
            weekday: 'long', 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric' 
        };
        const dateStr = today.toLocaleDateString('ar-SA', options);
        const dateElement = document.getElementById('statsCurrentDate');
        if (dateElement) {
            dateElement.textContent = dateStr;
        }
    }

    // تحديث إحصائيات المحطة
    async function updateStationStats() {
        const loadingEl = document.getElementById('statsLoading');
        const gridEl = document.getElementById('statsGrid');
        
        if (loadingEl) loadingEl.style.display = 'flex';
        if (gridEl) gridEl.style.display = 'none';
        
        try {
            // الحصول على بيانات المستخدم
            const userData = JSON.parse(localStorage.getItem('userData') || '{}');
            const station = userData.station || 'غير محدد';
            
            // جمع الإحصائيات من جميع الجداول
            const stats = await fetchStationStats(station);
            
            // عرض الإحصائيات
            displayStats(stats);
            
            // إخفاء رسالة التحميل وإظهار الشبكة
            if (loadingEl) loadingEl.style.display = 'none';
            if (gridEl) gridEl.style.display = 'grid';
            
            console.log('تم تحديث الإحصائيات:', stats);
            
        } catch (error) {
            console.error('خطأ في تحديث الإحصائيات:', error);
            showStatsError();
        }
    }

    // جلب إحصائيات المحطة من قاعدة البيانات
    async function fetchStationStats(stationName) {
        const today = new Date();
        const todayStr = today.toISOString().split('T')[0];
        
        // استخدام Supabase Client
        const supabase = window.supabaseClient;
        
        if (!supabase) {
            throw new Error('Supabase client غير متوفر');
        }
        
        try {
            const stats = {
                totalToday: 0,
                agriculturalReports: 0,
                hourlyReports: 0,
                dailyReports: 0,
                rainfallReports: 0,
                climateReports: 0,
                soilReports: 0,
                pendingReports: 0,
                completeReports: 0,
                stationName: stationName
            };
            
            // 1. التقارير الزراعية اليوم
            const { data: agriculturalData, error: agError } = await supabase
                .from('agricultural_reports')
                .select('*')
                .eq('station', stationName)
                .gte('created_at', todayStr)
                .lte('created_at', todayStr + ' 23:59:59');
            
            if (!agError && agriculturalData) {
                stats.agriculturalReports = agriculturalData.length;
                stats.totalToday += agriculturalData.length;
            }
            
            // 2. التقارير الساعية اليوم
            const { data: hourlyData, error: hrError } = await supabase
                .from('hourly_reports')
                .select('*')
                .eq('station_name', stationName)
                .gte('submission_date', todayStr)
                .lte('submission_date', todayStr);
            
            if (!hrError && hourlyData) {
                stats.hourlyReports = hourlyData.length;
                stats.totalToday += hourlyData.length;
            }
            
            // 3. التقارير اليومية
            const { data: dailyData, error: dailyError } = await supabase
                .from('daily_reports')
                .select('*')
                .eq('station', stationName)
                .gte('report_date', todayStr)
                .lte('report_date', todayStr);
            
            if (!dailyError && dailyData) {
                stats.dailyReports = dailyData.length;
                stats.totalToday += dailyData.length;
            }
            
            // 4. التقارير المطرية
            const { data: rainData, error: rainError } = await supabase
                .from('rainfall_reports')
                .select('*')
                .eq('observer_station', stationName)
                .gte('observation_date', todayStr)
                .lte('observation_date', todayStr);
            
            if (!rainError && rainData) {
                stats.rainfallReports = rainData.length;
                stats.totalToday += rainData.length;
            }
            
            // 5. التقارير المناخية
            const { data: climateData, error: climateError } = await supabase
                .from('climate_reports')
                .select('*')
                .eq('station', stationName)
                .gte('report_date', todayStr)
                .lte('report_date', todayStr);
            
            if (!climateError && climateData) {
                stats.climateReports = climateData.length;
                stats.totalToday += climateData.length;
            }
            
            // 6. درجات حرارة التربة
            const { data: soilData, error: soilError } = await supabase
                .from('soil_temperatures')
                .select('*')
                .eq('station', stationName)
                .gte('observation_date', todayStr)
                .lte('observation_date', todayStr);
            
            if (!soilError && soilData) {
                stats.soilReports = soilData.length;
                stats.totalToday += soilData.length;
            }
            
            // حساب التقارير المكتملة والمعلقة
            stats.completeReports = stats.totalToday;
            stats.pendingReports = calculatePendingReports(stats);
            
            return stats;
            
        } catch (error) {
            console.error('خطأ في جلب الإحصائيات:', error);
            throw error;
        }
    }
    
    // حساب التقارير المعلقة (مثال: 24 تقرير ساعي مطلوب يومياً)
    function calculatePendingReports(stats) {
        const expectedHourlyReports = 24; // 24 تقرير ساعي في اليوم
        const pendingHourly = Math.max(0, expectedHourlyReports - stats.hourlyReports);
        
        // يمكن إضافة حسابات أخرى للأنواع الأخرى من التقارير
        
        return pendingHourly;
    }

    // عرض الإحصائيات
    function displayStats(stats) {
        const gridEl = document.getElementById('statsGrid');
        if (!gridEl) return;
        
        const iconMap = {
            'total': 'fas fa-file-alt',
            'agricultural': 'fas fa-leaf',
            'hourly': 'fas fa-clock',
            'daily': 'fas fa-calendar-day',
            'rainfall': 'fas fa-cloud-rain',
            'climate': 'fas fa-wind',
            'soil': 'fas fa-temperature-half',
            'pending': 'fas fa-clock',
            'complete': 'fas fa-check-circle'
        };
        
        const items = [
            {
                id: 'totalToday',
                label: 'إجمالي التقارير اليوم',
                count: stats.totalToday,
                type: 'total',
                className: stats.totalToday > 0 ? 'complete' : 'danger'
            },
            {
                id: 'agriculturalReports',
                label: 'تقارير زراعية',
                count: stats.agriculturalReports,
                type: 'agricultural',
                className: stats.agriculturalReports > 0 ? 'complete' : 'warning'
            },
            {
                id: 'hourlyReports',
                label: 'تقارير ساعية',
                count: stats.hourlyReports,
                type: 'hourly',
                className: stats.hourlyReports >= 24 ? 'complete' : 
                         stats.hourlyReports > 12 ? 'warning' : 'danger'
            },
            {
                id: 'dailyReports',
                label: 'تقارير يومية',
                count: stats.dailyReports,
                type: 'daily',
                className: stats.dailyReports > 0 ? 'complete' : 'warning'
            },
            {
                id: 'rainfallReports',
                label: 'تقارير مطرية',
                count: stats.rainfallReports,
                type: 'rainfall',
                className: stats.rainfallReports > 0 ? 'complete' : 'info'
            },
            {
                id: 'pendingReports',
                label: 'تقارير معلقة',
                count: stats.pendingReports,
                type: 'pending',
                className: stats.pendingReports === 0 ? 'complete' : 
                         stats.pendingReports < 5 ? 'warning' : 'danger'
            }
        ];
        
        gridEl.innerHTML = items.map(item => `
            <div class="stat-item ${item.className}" id="stat-${item.id}">
                <div class="stat-icon">
                    <i class="${iconMap[item.type] || 'fas fa-chart-bar'}"></i>
                </div>
                <div class="stat-count">${item.count}</div>
                <div class="stat-label">${item.label}</div>
            </div>
        `).join('');
        
        // تحديث عنوان المحطة
        const stationNameEl = document.querySelector('.station-stats h5');
        if (stationNameEl && stats.stationName) {
            stationNameEl.innerHTML = `
                <i class="fas fa-chart-pie me-2"></i>
                إحصائيات محطة ${stats.stationName} - اليوم
            `;
        }
    }
    
    // عرض رسالة خطأ
    function showStatsError() {
        const gridEl = document.getElementById('statsGrid');
        if (!gridEl) return;
        
        gridEl.innerHTML = `
            <div class="col-12">
                <div class="alert alert-light text-center">
                    <i class="fas fa-exclamation-triangle text-warning me-2"></i>
                    <span>تعذر تحميل الإحصائيات. تأكد من اتصالك بالإنترنت.</span>
                    <br>
                    <button class="btn btn-sm btn-outline-light mt-2" onclick="updateStationStats()">
                        <i class="fas fa-redo me-1"></i>إعادة المحاولة
                    </button>
                </div>
            </div>
        `;
        
        const loadingEl = document.getElementById('statsLoading');
        if (loadingEl) loadingEl.style.display = 'none';
        gridEl.style.display = 'grid';
    }
    
    // جعل الدوال متاحة عالمياً
    window.updateStationStats = updateStationStats;
    
    // بدء النظام
    setTimeout(() => {
        if (window.supabaseClient) {
            initStatsSystem();
        } else {
            console.warn('Supabase client غير جاهز. سيتم المحاولة مرة أخرى...');
            setTimeout(() => {
                if (window.supabaseClient) initStatsSystem();
            }, 2000);
        }
    }, 1000);
});