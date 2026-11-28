// user-data.js - ملف محسن لجلب بيانات المستخدم
console.log('👤 تحميل بيانات المستخدم المحسنة...');

class UserDataManager {
    constructor() {
        this.userData = null;
        this.stationData = null;
        this.loadData();
    }
    
    loadData() {
        this.userData = this.loadUserData();
        this.stationData = this.loadStationData();
        console.log('📊 بيانات محملة:', { user: this.userData, station: this.stationData });
    }
    
    loadUserData() {
        try {
            // 1. جلب من currentUser (الجلسة الحالية)
            const currentUser = localStorage.getItem('currentUser');
            if (currentUser) {
                const user = JSON.parse(currentUser);
                if (this.isValidUser(user)) {
                    return this.formatUserData(user);
                }
            }
            
            // 2. جلب من userData (النسخة الاحتياطية)
            const userData = localStorage.getItem('userData');
            if (userData) {
                const user = JSON.parse(userData);
                if (this.isValidUser(user)) {
                    return this.formatUserData(user);
                }
            }
            
            // 3. البيانات الافتراضية
            return this.getDefaultUserData();
            
        } catch (error) {
            console.error('❌ خطأ في تحميل بيانات المستخدم:', error);
            return this.getDefaultUserData();
        }
    }
    
    loadStationData() {
        try {
            // 1. من بيانات المستخدم
            if (this.userData && this.userData.station) {
                const stationData = this.generateStationData(this.userData.station);
                if (stationData) return stationData;
            }
            
            // 2. من localStorage
            const storedStationData = localStorage.getItem('stationData');
            if (storedStationData) {
                const station = JSON.parse(storedStationData);
                if (this.isValidStation(station)) return station;
            }
            
            // 3. البيانات الافتراضية
            return this.getDefaultStationData();
            
        } catch (error) {
            console.error('❌ خطأ في تحميل بيانات المحطة:', error);
            return this.getDefaultStationData();
        }
    }
    
    isValidUser(user) {
        return user && (user.email || user.name || user.id);
    }
    
    isValidStation(station) {
        return station && station.name;
    }
    
    formatUserData(user) {
        return {
            id: user.id || `user-${Date.now()}`,
            name: this.getUserName(user),
            email: user.email || 'غير محدد',
            phone: user.phone || 'غير محدد',
            station: user.station || 'محطة دمشق',
            role: user.role || 'راصد جوي',
            status: user.status || 'active',
            loginTime: user.login_time || Date.now(),
            fullData: user
        };
    }
    
    getUserName(user) {
        if (user.first_name || user.father_name || user.last_name) {
            return `${user.first_name || ''} ${user.father_name || ''} ${user.last_name || ''}`.trim();
        }
        return user.name || 'مستخدم النظام';
    }
    
    generateStationData(stationName) {
        const stations = {
            'محطة دمشق': {
                id: 'DAM-01',
                name: 'محطة دمشق المركزية',
                code: 'DAM',
                location: 'دمشق، سوريا',
                altitude: '680 متر',
                coordinates: { lat: '33.5138', lon: '36.2765' },
                type: 'مركزية',
                established: '1950'
            },
            'محطة حلب': {
                id: 'ALP-01',
                name: 'محطة حلب',
                code: 'ALP',
                location: 'حلب، سوريا',
                altitude: '390 متر',
                coordinates: { lat: '36.2021', lon: '37.1343' },
                type: 'رئيسية',
                established: '1955'
            },
            'محطة اللاذقية': {
                id: 'LAT-01',
                name: 'محطة اللاذقية',
                code: 'LAT',
                location: 'اللاذقية، سوريا',
                altitude: '7 متر',
                coordinates: { lat: '35.5167', lon: '35.7833' },
                type: 'ساحلية',
                established: '1960'
            },
            // ... إضافة محطات أخرى
        };
        
        return stations[stationName] || {
            id: `ST-${Date.now()}`,
            name: stationName,
            code: this.generateStationCode(stationName),
            location: `${stationName}، سوريا`,
            altitude: 'غير محدد',
            coordinates: { lat: '0', lon: '0' },
            type: 'عامة'
        };
    }
    
    generateStationCode(name) {
        const codes = {
            'محطة دمشق': 'DAM', 'دمشق': 'DAM',
            'محطة حلب': 'ALP', 'حلب': 'ALP',
            'محطة اللاذقية': 'LAT', 'اللاذقية': 'LAT',
            'محطة طرطوس': 'TAR', 'طرطوس': 'TAR',
            'محطة حمص': 'HOM', 'حمص': 'HOM',
            'محطة حماه': 'HAM', 'حماه': 'HAM',
            'محطة دير الزور': 'DEZ', 'دير الزور': 'DEZ',
            'محطة الحسكة': 'HAS', 'الحسكة': 'HAS',
            'محطة الرقة': 'RAQ', 'الرقة': 'RAQ',
            'محطة السويداء': 'SWE', 'السويداء': 'SWE',
            'محطة درعا': 'DAR', 'درعا': 'DAR',
            'محطة القنيطرة': 'QUN', 'القنيطرة': 'QUN',
            'محطة إدلب': 'IDL', 'إدلب': 'IDL'
        };
        
        return codes[name] || name.substring(0, 3).toUpperCase();
    }
    
    getDefaultUserData() {
        return {
            id: 'guest-001',
            name: 'مستخدم النظام',
            email: 'guest@weather.gov.sy',
            phone: 'غير محدد',
            station: 'محطة دمشق المركزية',
            role: 'راصد جوي',
            status: 'guest',
            loginTime: Date.now()
        };
    }
    
    getDefaultStationData() {
        return {
            id: 'DAM-00',
            name: 'محطة دمشق المركزية',
            code: 'DAM',
            location: 'دمشق، سوريا',
            altitude: '680 متر',
            coordinates: { lat: '33.5138', lon: '36.2765' },
            type: 'مركزية',
            established: '1950'
        };
    }
    
    // دالة لتحديث بيانات المستخدم
    updateUserData(updates) {
        try {
            this.userData = { ...this.userData, ...updates };
            
            // تحديث localStorage
            localStorage.setItem('userData', JSON.stringify(this.userData));
            
            // تحديث currentUser إذا كان موجوداً
            const currentUser = localStorage.getItem('currentUser');
            if (currentUser) {
                const user = JSON.parse(currentUser);
                localStorage.setItem('currentUser', JSON.stringify({ ...user, ...updates }));
            }
            
            console.log('✅ تم تحديث بيانات المستخدم:', this.userData);
            return this.userData;
            
        } catch (error) {
            console.error('❌ خطأ في تحديث بيانات المستخدم:', error);
            return null;
        }
    }
    
    // دالة لتحديث بيانات المحطة
    updateStationData(updates) {
        try {
            this.stationData = { ...this.stationData, ...updates };
            localStorage.setItem('stationData', JSON.stringify(this.stationData));
            console.log('✅ تم تحديث بيانات المحطة:', this.stationData);
            return this.stationData;
        } catch (error) {
            console.error('❌ خطأ في تحديث بيانات المحطة:', error);
            return null;
        }
    }
    
    // دالة للحصول على معلومات العرض
    getDisplayInfo() {
        return {
            userName: this.userData.name,
            userStation: this.stationData.name,
            userRole: this.userData.role,
            userEmail: this.userData.email,
            stationCode: this.stationData.code,
            stationLocation: this.stationData.location,
            stationAltitude: this.stationData.altitude
        };
    }
    
    // دالة للتحقق من الجلسة
    checkSession() {
        const hasSession = !!localStorage.getItem('currentUser') || !!localStorage.getItem('userData');
        const isGuest = this.userData.status === 'guest';
        
        return {
            hasSession,
            isGuest,
            isValid: hasSession && !isGuest,
            user: this.userData,
            station: this.stationData
        };
    }
    
    // دالة لمسح البيانات
    clearData() {
        try {
            const keys = ['userData', 'stationData', 'currentUser'];
            keys.forEach(key => localStorage.removeItem(key));
            
            this.userData = this.getDefaultUserData();
            this.stationData = this.getDefaultStationData();
            
            console.log('🗑️ تم مسح جميع بيانات المستخدم');
            return true;
            
        } catch (error) {
            console.error('❌ خطأ في مسح البيانات:', error);
            return false;
        }
    }
    
    // دالة لتصدير البيانات
    exportData() {
        return {
            user: this.userData,
            station: this.stationData,
            exportDate: new Date().toISOString(),
            version: '1.0.0'
        };
    }
    
    // دالة لاستيراد البيانات
    importData(data) {
        try {
            if (data.user) {
                this.userData = data.user;
                localStorage.setItem('userData', JSON.stringify(data.user));
            }
            
            if (data.station) {
                this.stationData = data.station;
                localStorage.setItem('stationData', JSON.stringify(data.station));
            }
            
            console.log('✅ تم استيراد البيانات بنجاح');
            return true;
            
        } catch (error) {
            console.error('❌ خطأ في استيراد البيانات:', error);
            return false;
        }
    }
    
    // دالة لعرض بيانات التصحيح
    debugInfo() {
        console.group('🔍 معلومات تصحيح بيانات المستخدم');
        console.log('👤 بيانات المستخدم:', this.userData);
        console.log('🏢 بيانات المحطة:', this.stationData);
        console.log('💾 localStorage:', {
            currentUser: localStorage.getItem('currentUser'),
            userData: localStorage.getItem('userData'),
            stationData: localStorage.getItem('stationData')
        });
        console.log('🔍 حالة الجلسة:', this.checkSession());
        console.groupEnd();
        
        return this.exportData();
    }
}

// إنشاء مثيل المدير
const userManager = new UserDataManager();

// دالة لعرض بيانات المستخدم في الواجهة
function displayUserInfo() {
    try {
        const displayInfo = userManager.getDisplayInfo();
        const sessionInfo = userManager.checkSession();
        
        // تحديث عناصر الواجهة
        const elements = {
            'userName': displayInfo.userName,
            'userStation': displayInfo.userStation,
            'userRole': displayInfo.userRole
        };
        
        Object.entries(elements).forEach(([id, value]) => {
            const element = document.getElementById(id);
            if (element) {
                const icon = id === 'userName' ? 'fa-user' : 
                            id === 'userStation' ? 'fa-map-marker-alt' : 'fa-user-tie';
                
                element.innerHTML = `<i class="fas ${icon} me-2"></i>${value}`;
                
                // إضافة تلميح إذا كان ضيفاً
                if (sessionInfo.isGuest) {
                    element.classList.add('text-warning');
                    element.title = 'مستخدم ضيف - يرجى تسجيل الدخول';
                }
            }
        });
        
        // إضافة معلومات إضافية إذا كانت موجودة
        const extraInfo = document.getElementById('userExtraInfo');
        if (extraInfo) {
            extraInfo.innerHTML = `
                <small class="text-muted">
                    <i class="fas fa-envelope me-1"></i>${displayInfo.userEmail} |
                    <i class="fas fa-mountain me-1 ms-2"></i>${displayInfo.stationAltitude}
                </small>
            `;
        }
        
        // عرض تحذير إذا كان ضيفاً
        if (sessionInfo.isGuest) {
            showUserNotification('⚠️ أنت تستخدم النظام كضيف. بعض الميزات قد تكون محدودة.', 'warning');
        }
        
        console.log('✅ تم عرض بيانات المستخدم في الواجهة');
        
    } catch (error) {
        console.error('❌ خطأ في عرض بيانات المستخدم:', error);
        showUserNotification('❌ خطأ في تحميل بيانات المستخدم', 'error');
    }
}

// دالة لعرض إشعارات المستخدم
function showUserNotification(message, type = 'info', duration = 5000) {
    // استخدام نظام الإشعارات الموجود
    if (typeof showNotification === 'function') {
        showNotification(message, type, duration);
    } else {
        // بديل بسيط
        const alert = document.createElement('div');
        alert.className = `alert alert-${type} alert-dismissible fade show`;
        alert.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        
        const container = document.querySelector('.main-content') || document.body;
        container.prepend(alert);
        
        setTimeout(() => {
            if (alert.parentNode) {
                alert.remove();
            }
        }, duration);
    }
}

// دالة للتحقق من الجلسة وإعادة التوجيه
function checkAndRedirect() {
    const session = userManager.checkSession();
    const isLoginPage = window.location.pathname.includes('index.html') || 
                       window.location.pathname.includes('login');
    
    if (!session.isValid && !isLoginPage) {
        console.warn('⚠️ جلسة غير صالحة، إعادة التوجيه...');
        showUserNotification('⚠️ يرجى تسجيل الدخول للوصول إلى النظام', 'warning');
        
        setTimeout(() => {
            window.location.href = '../../../index.html';
        }, 3000);
        
        return false;
    }
    
    return true;
}

// التهيئة التلقائية عند تحميل الملف
console.log('✅ نظام بيانات المستخدم المحسن جاهز');

// جعل المدير والدوال متاحة عالمياً
window.userManager = userManager;
window.displayUserInfo = displayUserInfo;
window.showUserNotification = showUserNotification;
window.checkAndRedirect = checkAndRedirect;