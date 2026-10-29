// daily_stats.js - إحصائيات المحطة (محسوبة من جداول التقارير الفعلية)
console.log('📊 تحميل daily_stats.js (نسخة متوافقة مع قاعدة البيانات)');

class DailyStationStats {
    constructor() {
        this.cacheDuration = 5 * 60 * 1000; // 5 دقائق
        this.cache = {};
        this.userStation = null;
        this.init();
    }

    init() {
        this.loadUserStation();
        this.setupRefreshButton();
        this.loadStatistics();
        this.setupAutoRefresh();
        console.log('✅ إحصائيات المحطة جاهزة (محسوبة من الجداول)');
    }

    loadUserStation() {
        try {
            const ud = localStorage.getItem('currentUser');
            if (ud) {
                const u = JSON.parse(ud);
                this.userStation = u.station || "المحطة الرئيسية";
                const el = document.getElementById("userStation");
                if (el) el.textContent = this.userStation;
                console.log(`📍 المحطة الحالية: ${this.userStation}`);
            } else {
                this.userStation = "المحطة الرئيسية";
                console.warn('⚠️ لا توجد بيانات مستخدم، استخدام المحطة الافتراضية');
            }
        } catch(e) {
            console.error("❌ خطأ في تحميل بيانات المحطة:", e);
            this.userStation = "المحطة الرئيسية";
        }
    }

    async loadStatistics() {
        const loading = document.getElementById("statsLoading");
        const grid = document.getElementById("statsGrid");
        const summary = document.getElementById("statsSummary");
        const msg = document.getElementById("statsMessage");

        try {
            if (loading) loading.style.display = "block";
            if (grid) grid.style.display = "none";
            if (summary) summary.style.display = "none";
            if (msg) {
                msg.className = "stats-message info";
                msg.innerHTML = '<i class="fas fa-sync-alt fa-spin me-1"></i>جاري تحديث الإحصائيات...';
            }

            const today = new Date().toISOString().split('T')[0];
            const cacheKey = `${this.userStation}_${today}`;
            if (this.cache[cacheKey] && Date.now() - this.cache[cacheKey].timestamp < this.cacheDuration) {
                console.log('📦 استخدام الإحصائيات المخزنة مؤقتاً');
                this.updateUI(this.cache[cacheKey].data);
                if (loading) loading.style.display = "none";
                return;
            }

            let stats;
            try {
                stats = await this.fetchCountsFromTables();
                console.log('📈 الإحصائيات المحسوبة:', stats);
                if (msg && stats.total === 0 && stats.expected > 0) {
                    msg.className = "stats-message info";
                    msg.innerHTML = '<i class="fas fa-info-circle me-1"></i>لم يتم إرسال أي تقارير بعد لهذا اليوم';
                }
            } catch (err) {
                console.error('❌ فشل حساب الإحصائيات:', err);
                stats = this.getFallbackStats();
                if (msg) {
                    msg.className = "stats-message warning";
                    msg.innerHTML = '<i class="fas fa-exclamation-triangle me-1"></i>عرض إحصائيات تجريبية (تعذر الاتصال بقاعدة البيانات)';
                }
            }

            this.cache[cacheKey] = { timestamp: Date.now(), data: stats };
            this.updateUI(stats);
        } catch (e) {
            console.error('❌ خطأ عام في الإحصائيات:', e);
            if (msg) {
                msg.className = "stats-message danger";
                msg.innerHTML = '<i class="fas fa-exclamation-circle me-1"></i>حدث خطأ في تحميل الإحصائيات';
            }
        } finally {
            if (loading) loading.style.display = "none";
        }
    }

    // جلب أعداد التقارير من كل جدول حسب اليوم والمحطة
    async fetchCountsFromTables() {
        if (!window.supabase) throw new Error("Supabase غير متهيئ أو غير متاح");
        const today = new Date().toISOString().split('T')[0];
        const station = this.userStation;

        // تعريف الاستعلامات لكل نوع من التقارير
        const queries = [
            {
                name: 'hourly',
                table: 'hourly_reports',
                stationField: 'station_name',
                dateField: 'created_at',
                isTimestamp: true,
                max: 24
            },
            {
                name: 'daily',
                table: 'daily_reports',
                stationField: 'station',
                dateField: 'report_date',
                isTimestamp: false,
                max: 3
            },
            {
                name: 'rain',
                table: 'rainfall_reports',
                fallbackFields: ['station_name', 'observer_station'],
                dateField: 'observation_date',
                isTimestamp: false,
                max: 1
            },
            {
                name: 'agricultural',
                table: 'agricultural_reports',
                stationField: 'station',
                dateField: 'report_date',
                isTimestamp: false,
                max: 1
            },
            {
                name: 'soil',
                table: 'soil_temperatures',
                stationField: 'station',
                dateField: 'observation_date',
                isTimestamp: false,
                max: 4
            },
            {
                name: 'climate',
                table: 'climate_reports',
                stationField: 'user_station',
                dateField: 'report_date',
                isTimestamp: false,
                max: 4
            }
        ];

        const results = { hourly:0, daily:0, rain:0, agricultural:0, soil:0, climate:0 };

        for (const q of queries) {
            let count = 0;

            // إذا كان هناك عدة حقول بديلة (مثل rainfall_reports)
            if (q.fallbackFields) {
                for (const field of q.fallbackFields) {
                    try {
                        let query = window.supabase
                            .from(q.table)
                            .select('*', { count: 'exact', head: true })
                            .eq(field, station);
                        if (q.isTimestamp) {
                            query = query.gte(q.dateField, `${today}T00:00:00.000Z`)
                                       .lt(q.dateField, `${new Date(Date.now()+86400000).toISOString().split('T')[0]}T00:00:00.000Z`);
                        } else {
                            query = query.eq(q.dateField, today);
                        }
                        const { count: c, error } = await query;
                        if (!error && c !== null) {
                            count = c;
                            console.log(`✅ ${q.table} (${field}): ${count}`);
                            break;
                        }
                    } catch(e) {
                        console.warn(`⚠️ فشل الاستعلام على ${q.table} بحقل ${field}:`, e.message);
                    }
                }
            }
            // إذا كان هناك حقل محدد واحد
            else if (q.stationField) {
                try {
                    let query = window.supabase
                        .from(q.table)
                        .select('*', { count: 'exact', head: true })
                        .eq(q.stationField, station);
                    if (q.isTimestamp) {
                        const tomorrow = new Date(Date.now()+86400000).toISOString().split('T')[0];
                        query = query.gte(q.dateField, `${today}T00:00:00.000Z`)
                                   .lt(q.dateField, `${tomorrow}T00:00:00.000Z`);
                    } else {
                        query = query.eq(q.dateField, today);
                    }
                    const { count: c, error } = await query;
                    if (!error && c !== null) {
                        count = c;
                        console.log(`✅ ${q.table}: ${count}`);
                    } else if (error) {
                        console.warn(`⚠️ خطأ في ${q.table}:`, error.message);
                    }
                } catch(e) {
                    console.warn(`⚠️ استثناء في ${q.table}:`, e.message);
                }
            }

            results[q.name] = count;
        }

        // محاولة بديلة لـ daily_reports باستخدام station_name إذا station لم يعط نتيجة
        if (results.daily === 0) {
            try {
                const { count, error } = await window.supabase
                    .from('daily_reports')
                    .select('*', { count: 'exact', head: true })
                    .eq('station_name', station)
                    .eq('report_date', today);
                if (!error && count) results.daily = count;
                console.log(`✅ daily_reports باستخدام station_name: ${results.daily}`);
            } catch(e) {}
        }

        // محاولة بديلة لـ climate_reports باستخدام station
        if (results.climate === 0) {
            try {
                const { count, error } = await window.supabase
                    .from('climate_reports')
                    .select('*', { count: 'exact', head: true })
                    .eq('station', station)
                    .eq('report_date', today);
                if (!error && count) results.climate = count;
                console.log(`✅ climate_reports باستخدام station: ${results.climate}`);
            } catch(e) {}
        }

        // محاولة بديلة لـ hourly_reports باستخدام station
        if (results.hourly === 0) {
            try {
                const { count, error } = await window.supabase
                    .from('hourly_reports')
                    .select('*', { count: 'exact', head: true })
                    .eq('station', station)
                    .gte('created_at', `${today}T00:00:00.000Z`)
                    .lt('created_at', `${new Date(Date.now()+86400000).toISOString().split('T')[0]}T00:00:00.000Z`);
                if (!error && count) results.hourly = count;
                console.log(`✅ hourly_reports باستخدام station: ${results.hourly}`);
            } catch(e) {}
        }

        results.total = Object.values(results).reduce((a,b) => a+b, 0);
        results.expected = 24 + 3 + 1 + 1 + 4 + 4; // 37
        results.missing = Math.max(0, results.expected - results.total);
        return results;
    }

    getFallbackStats() {
        return {
            hourly: 0, daily: 0, rain: 0, agricultural: 0, soil: 0, climate: 0,
            total: 0, expected: 37, missing: 37
        };
    }

    updateUI(stats) {
        const maxMap = { hourly:24, daily:3, rain:1, agricultural:1, soil:4, climate:4 };
        const labels = {
            hourly: 'النشرات الساعية',
            daily: 'النشرات اليومية',
            rain: 'النشرات المطرية',
            agricultural: 'النشرات الزراعية',
            soil: 'نشرات التربة',
            climate: 'النشرات المناخية'
        };
        const icons = {
            hourly: 'fa-clock',
            daily: 'fa-calendar-day',
            rain: 'fa-cloud-showers-heavy',
            agricultural: 'fa-leaf',
            soil: 'fa-seedling',
            climate: 'fa-cloud-sun'
        };

        const grid = document.getElementById("statsGrid");
        if (!grid) {
            console.error("❌ العنصر statsGrid غير موجود في الصفحة!");
            return;
        }

        grid.innerHTML = '';
        for (let type of ['hourly','daily','rain','agricultural','soil','climate']) {
            const count = stats[type] || 0;
            const max = maxMap[type];
            const percent = max ? Math.min((count/max)*100, 100) : 0;
            let statusClass = 'danger';
            if (percent >= 100) statusClass = 'complete';
            else if (percent >= 50) statusClass = 'warning';
            else if (count > 0) statusClass = 'normal';

            const div = document.createElement('div');
            div.className = `stat-item ${statusClass}`;
            div.id = `stat-${type}`;
            div.innerHTML = `
                <div class="stat-icon ${statusClass}"><i class="fas ${icons[type]}"></i></div>
                <div class="stat-values">
                    <span class="stat-count" id="count-${type}">${count}</span>
                    <span class="stat-limit">من ${max}</span>
                </div>
                <div class="stat-label">${labels[type]}</div>
                <div class="stat-progress">
                    <div class="progress-bar ${statusClass}" id="progress-${type}" style="width: ${percent}%"></div>
                </div>
            `;
            grid.appendChild(div);
        }

        const totalActual = stats.total || 0;
        const totalMax = stats.expected || 37;
        const totalPercent = totalMax ? Math.round((totalActual/totalMax)*100) : 0;

        const totalEl = document.getElementById("totalPercentage");
        if (totalEl) {
            totalEl.textContent = `${totalPercent}%`;
            if (totalPercent >= 80) totalEl.className = "summary-percentage complete";
            else if (totalPercent >= 50) totalEl.className = "summary-percentage warning";
            else totalEl.className = "summary-percentage danger";
        }
        const detailsEl = document.getElementById("statsDetails");
        if (detailsEl) detailsEl.textContent = `${totalActual}/${totalMax} تقرير`;
        const gridEl = document.getElementById("statsGrid");
        const sumEl = document.getElementById("statsSummary");
        if (gridEl) gridEl.style.display = "grid";
        if (sumEl) sumEl.style.display = "block";

        const msgEl = document.getElementById("statsMessage");
        if (msgEl && !msgEl.innerHTML.includes('تجريبية') && !msgEl.innerHTML.includes('تعذر')) {
            if (totalPercent >= 90) msgEl.innerHTML = '<i class="fas fa-check-circle me-1"></i>🎉 ممتاز! تم إكمال معظم التقارير';
            else if (totalPercent > 0) msgEl.innerHTML = `<i class="fas fa-chart-line me-1"></i>تم إنجاز ${totalPercent}% من التقارير اليومية`;
            else msgEl.innerHTML = '<i class="fas fa-info-circle me-1"></i>لم يتم إرسال أي تقارير بعد لهذا اليوم';
        }
        console.log("🎨 تم تحديث واجهة الإحصائيات");
    }

    setupRefreshButton() {
        const btn = document.getElementById("refreshStatsBtn");
        if (btn) btn.addEventListener("click", () => this.refresh());
    }

    async refresh() {
        const btn = document.getElementById("refreshStatsBtn");
        if (btn) {
            const orig = btn.innerHTML;
            btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> جاري...';
            btn.disabled = true;
            await this.loadStatistics();
            setTimeout(() => { btn.innerHTML = orig; btn.disabled = false; }, 1000);
        } else {
            await this.loadStatistics();
        }
    }

    setupAutoRefresh() {
        setInterval(() => {
            if (document.visibilityState === 'visible') this.loadStatistics();
        }, 5 * 60 * 1000);
        document.addEventListener("visibilitychange", () => {
            if (document.visibilityState === 'visible') this.loadStatistics();
        });
    }
}

document.addEventListener("DOMContentLoaded", () => {
    setTimeout(() => {
        window.dailyStats = new DailyStationStats();
    }, 1000);
});

window.refreshDailyStats = () => {
    if (window.dailyStats) window.dailyStats.refresh();
};