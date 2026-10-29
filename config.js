// config.js - إعدادات التنسيق التلقائي (محدث - بدون توقيت محلي)
console.log('⚙️ تحميل إعدادات التنسيق التلقائي (UTC فقط)...');

// إعدادات التنسيق المتقدمة
const FORMAT_CONFIG = {
    // تمكين/تعطيل الميزات
    features: {
        autoFormat: true,
        autoDecimal: true,
        autoZeroPad: true,
        autoSignUpdate: true,
        enterNavigation: true,
        realTimeValidation: true,
        autoCalculate: true,
        smartCompletion: true,
        fieldHints: true,
        dailyStats: true,
        whatsappIntegration: true,
        draftAutoSave: true
    },
    
    // تنسيقات الحقول المحددة
    fieldFormats: {
        temperature: {
            decimalPlaces: 1,
            minValue: -20.0,
            maxValue: 60.0,
            pattern: /^-?\d{1,2}\.\d$/,
            placeholder: 'مثال: 25.5 أو -15.2',
            required: true,
            autoCalculate: true
        },
        humidity: {
            digits: 3,
            minValue: 1,
            maxValue: 100,
            pattern: /^\d{3}$/,
            placeholder: 'مثال: 075 أو 100',
            required: true,
            autoCalculate: true
        },
        vaporPressure: {
            decimalPlaces: 1,
            minValue: -50.0,
            maxValue: 50.0,
            pattern: /^-?\d{1,2}\.\d$/,
            placeholder: 'مثال: 18.5 أو -5.2',
            required: true,
            autoCalculate: true
        },
        direction: {
            digits: 2,
            minValue: 0,
            maxValue: 36,
            pattern: /^\d{2}$/,
            placeholder: 'مثال: 15 أو 36',
            required: true,
            autoCalculate: false
        },
        windSpeed: {
            digits: 2,
            minValue: 0,
            maxValue: 99,
            pattern: /^\d{2}$/,
            placeholder: 'مثال: 12 أو 99',
            required: true,
            autoCalculate: false
        },
        cloudCover: {
            digits: 1,
            minValue: 0,
            maxValue: 9, // تم التعديل من 8 إلى 9
            pattern: /^[0-9]$/, // تم التعديل من [0-8] إلى [0-9]
            placeholder: 'مثال: 3 أو 9', // تم التعديل من 8 إلى 9
            required: true,
            autoCalculate: false
        },
        utcTime: {
            pattern: /^([01]\d|2[0-3]):00$|^#$/,
            placeholder: 'مثال: 14:00 أو #',
            required: true
        }
    },
    
    // إعدادات الحقول (محدثة)
    fieldSettings: {
        // درجات الحرارة
        dryTemp: {
            name: 'درجة الحرارة الجافة',
            unit: '°C',
            category: 'temperature',
            icon: 'fa-temperature-high',
            importance: 'high'
        },
        wetTemp: {
            name: 'درجة الحرارة الرطبة',
            unit: '°C',
            category: 'temperature',
            icon: 'fa-temperature-low',
            importance: 'high'
        },
        dewPoint: {
            name: 'درجة الندى',
            unit: '°C',
            category: 'temperature',
            icon: 'fa-dewpoint',
            importance: 'medium',
            autoCalculateFrom: ['dryTemp', 'relativeHumidity']
        },
        relativeHumidity: {
            name: 'الرطوبة النسبية',
            unit: '%',
            category: 'humidity',
            icon: 'fa-tint',
            importance: 'high',
            autoCalculateFrom: ['dryTemp', 'wetTemp']
        },
        vaporPressure: {
            name: 'ضغط بخار الماء',
            unit: 'ميلبار',
            category: 'pressure',
            icon: 'fa-wind',
            importance: 'medium'
        },
        windDirection: {
            name: 'اتجاه الرياح',
            unit: 'درجة',
            category: 'wind',
            icon: 'fa-compass',
            importance: 'high'
        },
        windSpeed: {
            name: 'سرعة الرياح',
            unit: 'م/ثا',
            category: 'wind',
            icon: 'fa-wind',
            importance: 'high'
        },
        avgWindDirection: {
            name: 'متوسط اتجاه الرياح',
            unit: 'درجة',
            category: 'wind',
            icon: 'fa-compass',
            importance: 'medium'
        },
        avgWindSpeed: {
            name: 'متوسط سرعة الرياح',
            unit: 'م/ثا',
            category: 'wind',
            icon: 'fa-wind',
            importance: 'medium'
        },
        totalCloudCover: {
            name: 'التغطية السحابية',
            unit: '/9',
            category: 'cloud',
            icon: 'fa-cloud',
            importance: 'medium'
        },
        utcTime: {
            name: 'التوقيت العالمي',
            unit: 'UTC',
            category: 'time',
            icon: 'fa-globe',
            importance: 'high'
        }
    },
    
    // رسائل المستخدم (محدثة)
    messages: {
        formatSuccess: 'تم تنسيق القيمة تلقائياً',
        formatError: 'تنسيق غير صحيح',
        autoCalculated: 'تم حساب القيمة تلقائياً',
        requiredField: 'هذا الحقل مطلوب',
        validationSuccess: 'جميع الحقول صحيحة',
        validationError: 'يوجد أخطاء في النموذج',
        saveSuccess: 'تم حفظ التقرير بنجاح',
        saveError: 'فشل حفظ التقرير',
        draftSaved: 'تم حفظ المسودة',
        whatsappReady: 'التقرير جاهز للمشاركة',
        connectionError: 'مشكلة في الاتصال',
        dailyStatsUpdated: 'تم تحديث الإحصائيات',
        utcOnly: 'يتم استخدام التوقيت العالمي (UTC) فقط'
    },
    
    // التوقيتات والتأخيرات
    timings: {
        hintDisplay: 3000,    // 3 ثوانٍ
        animationDuration: 500, // 0.5 ثانية
        debounceDelay: 300,    // 0.3 ثانية
        autoSaveInterval: 30000, // 30 ثانية
        statsRefreshInterval: 60000, // 60 ثانية
        notificationTimeout: 5000 // 5 ثوانٍ
    },
    
    // ألوان ومظاهر
    colors: {
        success: '#28a745',
        error: '#dc3545',
        warning: '#ffc107',
        info: '#17a2b8',
        primary: '#3498db',
        secondary: '#6c757d',
        temperature: '#e74c3c',
        humidity: '#3498db',
        wind: '#2ecc71',
        cloud: '#95a5a6',
        time: '#9b59b6'
    },
    
    // إعدادات قاعدة البيانات (محدثة)
    database: {
        tableName: 'climate_reports',
        draftTableName: 'climate_drafts',
        userTableName: 'users',
        maxRetries: 3,
        retryDelay: 1000,
        batchSize: 10,
        localStorageBackup: true,
        // الأعمدة الجديدة بعد حذف التوقيت المحلي
        columns: {
            required: ['utc_time', 'dry_temperature', 'wet_temperature', 'relative_humidity'],
            optional: ['vapor_pressure', 'dew_point', 'wind_direction', 'wind_speed', 'avg_wind_direction', 'avg_wind_speed', 'total_cloud_cover']
        }
    },
    
    // إعدادات الواتساب (محدثة)
    whatsapp: {
        enabled: true,
        format: 'detailed',
        includeStation: true,
        includeObserver: true,
        includeTimestamp: true,
        includeValidation: true,
        timeFormat: 'UTC'
    },
    
    // إعدادات التطوير
    development: {
        debugMode: false,
        testDataEnabled: true,
        controlPanelEnabled: true,
        logLevel: 'info',
        performanceMonitoring: true,
        utcOnly: true // تم تمكين وضع UTC فقط
    }
};

// وظائف مساعدة (محدثة)
const CONFIG_HELPERS = {
    // الحصول على إعدادات حقل معين
    getFieldConfig: function(fieldId) {
        return FORMAT_CONFIG.fieldSettings[fieldId] || null;
    },
    
    // الحصول على تنسيق حقل معين
    getFieldFormat: function(fieldId) {
        const fieldConfig = this.getFieldConfig(fieldId);
        if (!fieldConfig) return null;
        
        return FORMAT_CONFIG.fieldFormats[fieldConfig.category] || null;
    },
    
    // التحقق مما إذا كان الحقل مطلوباً
    isFieldRequired: function(fieldId) {
        const format = this.getFieldFormat(fieldId);
        return format ? format.required : false;
    },
    
    // الحصول على مثال للحقل
    getFieldExample: function(fieldId) {
        const format = this.getFieldFormat(fieldId);
        return format ? format.placeholder : 'تنسيق غير معروف';
    },
    
    // التحقق من تمكين الميزة
    isFeatureEnabled: function(featureName) {
        return FORMAT_CONFIG.features[featureName] === true;
    },
    
    // الحصول على رسالة
    getMessage: function(messageKey) {
        return FORMAT_CONFIG.messages[messageKey] || '';
    },
    
    // التحقق من وقت UTC
    validateUTCTime: function(time) {
        if (time === '#') return true;
        
        const pattern = /^([01]\d|2[0-3]):00$/;
        return pattern.test(time);
    },
    
    // توليد تلميح UTC
    getUTCHint: function() {
        const now = new Date();
        const utcHour = now.getUTCHours().toString().padStart(2, "0");
        return `الوقت الحالي (UTC): ${utcHour}:00`;
    },
    
    // تحديث الإعدادات
    updateConfig: function(newConfig) {
        Object.assign(FORMAT_CONFIG, newConfig);
        console.log('⚙️ تم تحديث الإعدادات (UTC فقط)');
    },
    
    // إعادة تعيين الإعدادات
    resetConfig: function() {
        // يمكن إعادة التعيين للإعدادات الافتراضية
        console.warn('⚠️ إعادة تعيين الإعدادات غير مدعومة في هذه النسخة');
    },
    
    // تصدير الإعدادات
    exportConfig: function() {
        return JSON.stringify(FORMAT_CONFIG, null, 2);
    },
    
    // استيراد الإعدادات
    importConfig: function(configString) {
        try {
            const newConfig = JSON.parse(configString);
            this.updateConfig(newConfig);
            return true;
        } catch (error) {
            console.error('❌ خطأ في استيراد الإعدادات:', error);
            return false;
        }
    }
};

// تهيئة الإعدادات
function initializeConfig() {
    console.log('⚙️ تهيئة إعدادات النظام (UTC فقط)...');
    
    // تحميل الإعدادات المحفوظة
    const savedConfig = localStorage.getItem('climateFormatConfig');
    if (savedConfig) {
        try {
            const parsedConfig = JSON.parse(savedConfig);
            CONFIG_HELPERS.updateConfig(parsedConfig);
            console.log('✅ تم تحميل الإعدادات المحفوظة (UTC فقط)');
        } catch (error) {
            console.error('❌ خطأ في تحميل الإعدادات:', error);
        }
    }
    
    // حفظ الإعدادات تلقائياً
    if (FORMAT_CONFIG.database.localStorageBackup) {
        setInterval(() => {
            localStorage.setItem('climateFormatConfig', CONFIG_HELPERS.exportConfig());
            console.log('💾 تم حفظ الإعدادات تلقائياً (UTC فقط)');
        }, 60000); // كل دقيقة
    }
    
    // تسجيل الإعدادات النشطة
    if (FORMAT_CONFIG.development.debugMode) {
        console.log('🔍 الإعدادات النشطة (UTC فقط):', FORMAT_CONFIG);
    }
    
    return FORMAT_CONFIG;
}

// تصدير الإعدادات
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        FORMAT_CONFIG,
        CONFIG_HELPERS,
        initializeConfig
    };
} else {
    window.FORMAT_CONFIG = FORMAT_CONFIG;
    window.CONFIG_HELPERS = CONFIG_HELPERS;
    window.initializeConfig = initializeConfig;
    
    // تهيئة تلقائية
    document.addEventListener('DOMContentLoaded', function() {
        setTimeout(() => {
            initializeConfig();
            console.log('✅ تم تحميل إعدادات التنسيق التلقائي (UTC فقط)');
        }, 500);
    });
}

console.log('⚙️ تم تحميل إعدادات التنسيق التلقائي (UTC فقط)');