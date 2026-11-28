// daily_settings.js - إعدادات تطبيق الملخص اليومي

const APP_SETTINGS = {
    // إعدادات عامة
    autoSave: true,
    autoSaveInterval: 30000, // 30 ثانية
    validation: {
        strictMode: true,
        showHints: true
    },
    
    // إعدادات الإشعارات
    notifications: {
        success: true,
        errors: true,
        warnings: true,
        sound: false
    },
    
    // إعدادات التصدير
    export: {
        defaultFormat: 'json',
        includeMetadata: true,
        timestampFormat: 'arabic'
    },
    
    // إعدادات الواتساب
    whatsapp: {
        enabled: false,
        defaultNumbers: [],
        messageTemplate: 'default'
    },
    
    // إعدادات قاعدة البيانات
    database: {
        autoBackup: true,
        backupInterval: 24 * 60 * 60 * 1000, // 24 ساعة
        maxBackups: 30
    }
};

// تهيئة الإعدادات
function initSettings() {
    loadSettings();
    setupAutoSave();
    setupBackup();
}

// تحميل الإعدادات المحفوظة
function loadSettings() {
    try {
        const savedSettings = JSON.parse(localStorage.getItem('dailyAppSettings') || '{}');
        Object.assign(APP_SETTINGS, savedSettings);
        console.log('تم تحميل الإعدادات:', APP_SETTINGS);
    } catch (error) {
        console.error('خطأ في تحميل الإعدادات:', error);
    }
}

// حفظ الإعدادات
function saveSettings(newSettings = {}) {
    try {
        Object.assign(APP_SETTINGS, newSettings);
        localStorage.setItem('dailyAppSettings', JSON.stringify(APP_SETTINGS));
        console.log('تم حفظ الإعدادات:', APP_SETTINGS);
        if (typeof showNotification === 'function') {
            showNotification('تم حفظ الإعدادات بنجاح', 'success');
        }
        return true;
    } catch (error) {
        console.error('خطأ في حفظ الإعدادات:', error);
        if (typeof showNotification === 'function') {
            showNotification('فشل في حفظ الإعدادات', 'error');
        }
        return false;
    }
}

// جمع بيانات النموذج للمسودة
function collectFormDataForSettings() {
    try {
        const userData = JSON.parse(localStorage.getItem('currentUser') || '{}');
        const reportType = document.querySelector('input[name="reportType"]:checked');
        
        const formData = {
            // بيانات المستخدم
            user_id: userData.id || null,
            observer_name: document.getElementById('userName') ? document.getElementById('userName').textContent : '',
            station: document.getElementById('userStation') ? document.getElementById('userStation').textContent : '',
            observer_role: document.getElementById('userRole') ? document.getElementById('userRole').textContent : '',
            
            // بيانات الملخص
            report_date: new Date().toISOString().split('T')[0],
            display_date: document.getElementById('dataCollectionDate') ? document.getElementById('dataCollectionDate').value : '',
            report_type: reportType ? reportType.value : '24h',
            
            // درجات الحرارة
            min_temperature: document.getElementById('minTemp') ? document.getElementById('minTemp').value : '',
            max_temperature: document.getElementById('maxTemp') ? document.getElementById('maxTemp').value : '',
            
            // الهطول والثلج
            precipitation: document.getElementById('precipitation') ? document.getElementById('precipitation').value : '',
            snow_thickness: document.getElementById('snowThickness') ? document.getElementById('snowThickness').value : '',
            
            // بيانات النظام
            status: 'auto_draft',
            auto_saved_at: new Date().toISOString()
        };
        
        return formData;
    } catch (error) {
        console.error('خطأ في جمع بيانات النموذج:', error);
        return {};
    }
}

// إعداد الحفظ التلقائي
function setupAutoSave() {
    if (!APP_SETTINGS.autoSave) return;
    
    setInterval(() => {
        if (isFormModified()) {
            saveDraftAuto();
        }
    }, APP_SETTINGS.autoSaveInterval);
}

// الحفظ التلقائي للمسودة
function saveDraftAuto() {
    try {
        const formData = collectFormDataForSettings();
        
        const autoDrafts = JSON.parse(localStorage.getItem('dailyAutoDrafts') || '[]');
        const draftData = {
            ...formData,
            saved_at: new Date().toISOString(),
            draft_id: 'auto_draft_' + Date.now()
        };
        
        // حفظ فقط آخر 5 مسودات تلقائية
        autoDrafts.unshift(draftData);
        if (autoDrafts.length > 5) {
            autoDrafts.pop();
        }
        
        localStorage.setItem('dailyAutoDrafts', JSON.stringify(autoDrafts));
        console.log('تم الحفظ التلقائي للمسودة');
        
    } catch (error) {
        console.error('خطأ في الحفظ التلقائي:', error);
    }
}

// التحقق إذا كان النموذج معدل
function isFormModified() {
    const requiredFields = [
        'minTemp', 'maxTemp', 'precipitation', 'snowThickness'
    ];
    
    return requiredFields.some(fieldId => {
        const field = document.getElementById(fieldId);
        return field && field.value.trim() !== '';
    });
}

// إعداد النسخ الاحتياطي
function setupBackup() {
    if (!APP_SETTINGS.database.autoBackup) return;
    
    setInterval(() => {
        createBackup();
    }, APP_SETTINGS.database.backupInterval);
}

// إنشاء نسخة احتياطية
function createBackup() {
    try {
        const backups = JSON.parse(localStorage.getItem('dailyBackups') || '[]');
        const now = new Date();
        
        // جمع البيانات الحالية
        const backupData = {
            timestamp: now.toISOString(),
            date: now.toLocaleDateString('ar-EG'),
            data: {
                drafts: JSON.parse(localStorage.getItem('dailyDrafts') || '[]'),
                autoDrafts: JSON.parse(localStorage.getItem('dailyAutoDrafts') || '[]'),
                settings: APP_SETTINGS,
                stats: JSON.parse(localStorage.getItem('dailySubmissionStats') || '{}')
            }
        };
        
        backups.unshift(backupData);
        
        // الحفاظ على العدد الأقصى للنسخ الاحتياطية
        if (backups.length > APP_SETTINGS.database.maxBackups) {
            backups.splice(APP_SETTINGS.database.maxBackups);
        }
        
        localStorage.setItem('dailyBackups', JSON.stringify(backups));
        console.log('تم إنشاء نسخة احتياطية');
        
    } catch (error) {
        console.error('خطأ في إنشاء النسخة الاحتياطية:', error);
    }
}

// استعادة من نسخة احتياطية
function restoreFromBackup(backupIndex = 0) {
    try {
        const backups = JSON.parse(localStorage.getItem('dailyBackups') || '[]');
        
        if (backups.length === 0) {
            if (typeof showNotification === 'function') {
                showNotification('لا توجد نسخ احتياطية', 'warning');
            }
            return false;
        }
        
        if (backupIndex >= backups.length) {
            if (typeof showNotification === 'function') {
                showNotification('فهرس النسخة الاحتياطية غير صالح', 'error');
            }
            return false;
        }
        
        const backup = backups[backupIndex];
        
        if (confirm('هل تريد استعادة النسخة الاحتياطية من ' + backup.date + '؟ سيتم استبدال البيانات الحالية.')) {
            // استعادة البيانات
            if (backup.data.drafts) {
                localStorage.setItem('dailyDrafts', JSON.stringify(backup.data.drafts));
            }
            if (backup.data.autoDrafts) {
                localStorage.setItem('dailyAutoDrafts', JSON.stringify(backup.data.autoDrafts));
            }
            if (backup.data.settings) {
                Object.assign(APP_SETTINGS, backup.data.settings);
                localStorage.setItem('dailyAppSettings', JSON.stringify(APP_SETTINGS));
            }
            if (backup.data.stats) {
                localStorage.setItem('dailySubmissionStats', JSON.stringify(backup.data.stats));
            }
            
            if (typeof showNotification === 'function') {
                showNotification('تم استعادة النسخة الاحتياطية بنجاح', 'success');
            }
            location.reload();
            return true;
        }
        
    } catch (error) {
        console.error('خطأ في استعادة النسخة الاحتياطية:', error);
        if (typeof showNotification === 'function') {
            showNotification('فشل في استعادة النسخة الاحتياطية', 'error');
        }
        return false;
    }
}

// إعدادات التحقق
function getValidationSettings() {
    return APP_SETTINGS.validation;
}

// تحديث إعدادات التحقق
function updateValidationSettings(newSettings) {
    APP_SETTINGS.validation = { ...APP_SETTINGS.validation, ...newSettings };
    saveSettings();
}

// جعل الدوال متاحة globally
window.saveSettings = saveSettings;
window.loadSettings = loadSettings;
window.restoreFromBackup = restoreFromBackup;
window.getValidationSettings = getValidationSettings;
window.updateValidationSettings = updateValidationSettings;

// التهيئة عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
    initSettings();
});