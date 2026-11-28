class UserManager {
    constructor() {
        this.userData = null;
        this.sources = ['cache', 'session', 'local', 'supabase'];
    }

    async initialize() {
        await this.loadUserFromFastestSource();
        if (this.userData) {
            this.displayUserInfo();
            this.fillAllForms();
        } else {
            this.redirectToLogin();
        }
    }

    async loadUserFromFastestSource() {
        // جلب البيانات من أسرع مصدر بالتتابع
        for (const source of this.sources) {
            try {
                const userData = await this.getUserFromSource(source);
                if (userData) {
                    this.userData = userData;
                    // حفظ في الكاش للمستقبل
                    this.cacheUserData(userData);
                    console.log(`User data loaded from: ${source}`);
                    return;
                }
            } catch (error) {
                console.warn(`Failed to load from ${source}:`, error);
            }
        }
    }

    async getUserFromSource(source) {
        switch (source) {
            case 'cache':
                return this.getFromMemoryCache();
            case 'session':
                return this.getFromSessionStorage();
            case 'local':
                return this.getFromLocalStorage();
            case 'supabase':
                return await this.getFromSupabase();
            default:
                return null;
        }
    }

    getFromMemoryCache() {
        // محاكاة للكاش في الذاكرة (في تطبيق حقيقي يمكن استخدام Map أو WeakMap)
        return this.userData;
    }

    getFromSessionStorage() {
        const data = sessionStorage.getItem('userData');
        return data ? JSON.parse(data) : null;
    }

    getFromLocalStorage() {
        const data = localStorage.getItem('userData');
        return data ? JSON.parse(data) : null;
    }

    async getFromSupabase() {
        if (typeof supabase === 'undefined') return null;
        
        try {
            const { data: { user }, error } = await supabase.auth.getUser();
            if (error || !user) return null;

            // جلب البيانات الإضافية من الجدول
            const { data: profile, error: profileError } = await supabase
                .from('users')
                .select('*')
                .eq('id', user.id)
                .single();

            if (profileError) return null;

            return {
                id: user.id,
                email: user.email,
                name: profile.full_name || user.email,
                station: profile.station || 'غير محدد',
                role: profile.role || 'موظف',
                phone: profile.phone || '',
                department: profile.department || ''
            };
        } catch (error) {
            console.error('Supabase error:', error);
            return null;
        }
    }

    cacheUserData(userData) {
        // حفظ في جميع مصادر التخزين للاستخدام المستقبلي
        try {
            sessionStorage.setItem('userData', JSON.stringify(userData));
            localStorage.setItem('userData', JSON.stringify(userData));
        } catch (error) {
            console.warn('Failed to cache user data:', error);
        }
    }

    displayUserInfo() {
        if (!this.userData) return;
        
        const userNameElement = document.getElementById('userName');
        const userStationElement = document.getElementById('userStation');
        const userRoleElement = document.getElementById('userRole');
        
        if (userNameElement) userNameElement.textContent = this.userData.name;
        if (userStationElement) userStationElement.textContent = this.userData.station;
        if (userRoleElement) userRoleElement.textContent = this.userData.role;
    }

    fillAllForms() {
        if (!this.userData) return;
        
        // تعبئة جميع النماذج ببيانات المستخدم
        const stationElements = document.querySelectorAll('[id$="StationName"]');
        const reporterElements = document.querySelectorAll('[id$="ReporterName"]');
        
        stationElements.forEach(el => {
            el.textContent = this.userData.station;
        });
        
        reporterElements.forEach(el => {
            el.textContent = this.userData.name;
        });
    }

    redirectToLogin() {
        window.location.href = '../../index.html';
    }

    logout() {
        // مسح البيانات من جميع المصادر
        this.userData = null;
        sessionStorage.removeItem('userData');
        localStorage.removeItem('userData');
        
        // تسجيل الخروج من Supabase
        if (typeof supabase !== 'undefined') {
            supabase.auth.signOut();
        }
        
        this.redirectToLogin();
    }

    getCurrentUser() {
        return this.userData;
    }

    updateUserData(updates) {
        this.userData = { ...this.userData, ...updates };
        this.cacheUserData(this.userData);
        this.displayUserInfo();
        this.fillAllForms();
    }
}

// إنشاء نسخة عامة
const userManager = new UserManager();