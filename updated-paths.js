// js/updated-paths.js - نظام إدارة المسارات المحدثة
console.log('🔄 تحميل نظام المسارات المحدثة...');

const UPDATED_SYSTEM_PATHS = {
    // المسارات الرئيسية
    MAIN: 'main.html',
    LOGIN: 'index.html',
    
    // مسارات النماذج والتقارير المحدثة
    HOURLY_REPORTS: 'pages/hourly/hourly_send/hourly_reports.html',
    DAILY_REPORTS: 'pages/daily/daily_send/daily.html',
    RAINFALL_REPORTS: 'pages/rain/rain_send/rainfall_reports.html',
    CLIMATE_HOURLY: 'pages/h_climate/h_climate_send/climate_hourly_reports.html',
    SOIL_TEMPERATURE: 'pages/soil/soil_send/soil-send.html',
    AGRICULTURAL_REPORTS: 'pages/arg/send-argicultural/agricultural_reports.html',
    
    // مسارات الدعم الفني
    FIX_EQUIPMENT: 'pages/fix/fix.html',
    FIX_TELECOMM: 'pages/fix/fix-tel.html',
    
    // مسارات الإدارة
    STATION_MANAGER: 'station-manager.html',
    CENTER_MANAGER: 'center-manager.html',
    MANAGER_DASHBOARD: 'manager-dashboard.html',
    
    // مسارات الدعم
    IT_SUPPORT: 'it.html'
};

// دالة للحصول على المسار الصحيح
function getSystemPath(pathKey) {
    const path = UPDATED_SYSTEM_PATHS[pathKey];
    if (!path) {
        console.error(`❌ مسار غير معروف: ${pathKey}`);
        return 'main.html';
    }
    return path;
}

// دالة للتنقل إلى صفحة محددة
function navigateTo(pathKey) {
    const path = getSystemPath(pathKey);
    window.location.href = path;
}

// دالة لفتح صفحة في نافذة جديدة
function openInNewTab(pathKey) {
    const path = getSystemPath(pathKey);
    window.open(path, '_blank');
}

// جعل الدوال متاحة عالمياً
window.getSystemPath = getSystemPath;
window.navigateTo = navigateTo;
window.openInNewTab = openInNewTab;
window.UPDATED_SYSTEM_PATHS = UPDATED_SYSTEM_PATHS;

console.log('✅ تم تحميل نظام المسارات المحدثة بنجاح');