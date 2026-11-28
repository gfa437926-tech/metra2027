// missing-data-handler.js - معالج البيانات المفقودة (محدث - بدون توقيت محلي)
console.log('⚠️ تحميل معالج البيانات المفقودة (#) (UTC فقط)...');

// تهيئة معالج البيانات المفقودة
function initializeMissingDataHandler() {
    console.log('🔧 تهيئة معالج البيانات المفقودة (UTC فقط)...');
    
    // إعداد أزرار # السريعة
    setupHashQuickButtons();
    
    // إعداد زر تعيين البيانات المفقودة
    setupMissingDataButton();
    
    // إعداد زر عرض الأمثلة
    setupExamplesButton();
    
    // إضافة معالجات الأحداث للحقول
    setupFieldHashHandlers();
    
    console.log('✅ تم تهيئة معالج البيانات المفقودة (UTC فقط)');
}

// إعداد أزرار # السريعة
function setupHashQuickButtons() {
    const fields = [
        'utcTime', 'dryTemp', 'wetTemp', 'dewPoint', 'vaporPressure',
        'relativeHumidity', 'windDirection', 'windSpeed',
        'avgWindDirection', 'avgWindSpeed', 'totalCloudCover'
    ];
    
    fields.forEach(fieldId => {
        const input = document.getElementById(fieldId);
        if (input) {
            // إضافة زر سريع
            const quickButton = document.createElement('button');
            quickButton.type = 'button';
            quickButton.className = 'hash-quick-btn';
            quickButton.innerHTML = '#';
            quickButton.title = 'تعيين كبيانات غير متوفرة';
            quickButton.dataset.field = fieldId;
            
            quickButton.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                
                const field = document.getElementById(this.dataset.field);
                if (field) {
                    field.value = '#';
                    field.dispatchEvent(new Event('input'));
                    field.dispatchEvent(new Event('change'));
                    field.focus();
                    
                    // إظهار تلميحة
                    showHashAppliedHint(fieldId);
                }
            });
            
            const wrapper = input.closest('.auto-format-wrapper') || input.parentElement;
            if (wrapper) {
                wrapper.appendChild(quickButton);
            }
        }
    });
}

// إعداد زر تعيين البيانات المفقودة
function setupMissingDataButton() {
    const button = document.getElementById('setMissingDataBtn');
    if (!button) {
        // إنشاء الزر إذا لم يكن موجوداً
        const buttonContainer = document.querySelector('.text-center.mt-4');
        if (buttonContainer) {
            const newButton = document.createElement('button');
            newButton.type = 'button';
            newButton.className = 'btn btn-info btn-custom';
            newButton.id = 'setMissingDataBtn';
            newButton.innerHTML = '<i class="fas fa-question-circle me-1"></i>تعيين بيانات مفقودة';
            newButton.title = 'تعيين # لجميع الحقول كبيانات غير متوفرة (UTC فقط)';
            
            // إضافة قبل زر واتساب
            const whatsappBtn = document.getElementById('whatsappBtn');
            if (whatsappBtn) {
                buttonContainer.insertBefore(newButton, whatsappBtn);
            } else {
                buttonContainer.appendChild(newButton);
            }
            
            newButton.addEventListener('click', function() {
                setAllFieldsToMissingData();
            });
            
            console.log('✅ تم إنشاء زر تعيين البيانات المفقودة (UTC فقط)');
        }
    } else {
        button.addEventListener('click', function() {
            setAllFieldsToMissingData();
        });
    }
}

// تعيين جميع الحقول كبيانات مفقودة
function setAllFieldsToMissingData() {
    if (confirm('هل تريد تعيين # لجميع الحقول كبيانات غير متوفرة؟ سيتم مسح أي قيم حالية. (UTC فقط)')) {
        const fields = [
            'utcTime', 'dryTemp', 'wetTemp', 'dewPoint', 'vaporPressure',
            'relativeHumidity', 'windDirection', 'windSpeed',
            'avgWindDirection', 'avgWindSpeed', 'totalCloudCover'
        ];
        
        let count = 0;
        
        fields.forEach(fieldId => {
            const input = document.getElementById(fieldId);
            if (input) {
                const currentValue = input.value;
                if (currentValue !== '#') {
                    input.value = '#';
                    input.dispatchEvent(new Event('input'));
                    input.dispatchEvent(new Event('change'));
                    count++;
                }
            }
        });
        
        if (count > 0) {
            showNotificationSafe(`✅ تم تعيين # لـ ${count} حقول كبيانات غير متوفرة (UTC فقط)`, 'success');
        } else {
            showNotificationSafe('ℹ️ جميع الحقول بالفعل تحتوي على # (UTC فقط)', 'info');
        }
    }
}

// إعداد زر عرض الأمثلة
function setupExamplesButton() {
    // إنشاء زر العرض إذا لم يكن موجوداً
    const buttonContainer = document.querySelector('.text-center.mt-4');
    if (buttonContainer && !document.getElementById('missingDataDemoBtn')) {
        const examplesButton = document.createElement('button');
        examplesButton.type = 'button';
        examplesButton.className = 'btn btn-secondary btn-custom';
        examplesButton.id = 'missingDataDemoBtn';
        examplesButton.innerHTML = '<i class="fas fa-question me-1"></i>عرض أمثلة #';
        examplesButton.title = 'عرض أمثلة لاستخدام # في البيانات المفقودة (UTC فقط)';
        
        // إضافة الزر
        buttonContainer.appendChild(examplesButton);
        
        examplesButton.addEventListener('click', function() {
            showMissingDataExamples();
        });
        
        console.log('✅ تم إنشاء زر عرض الأمثلة (UTC فقط)');
    }
}

// عرض أمثلة استخدام #
function showMissingDataExamples() {
    const examples = [
        {
            title: 'مثال 1: بيانات كاملة (UTC فقط)',
            description: 'جميع الأجهزة تعمل بشكل طبيعي',
            data: {
                utcTime: '14:00',
                dryTemp: '25.5',
                wetTemp: '20.3',
                relativeHumidity: '075',
                windDirection: '15',
                windSpeed: '12'
            }
        },
        {
            title: 'مثال 2: جهاز معطل واحد (UTC فقط)',
            description: 'مقياس الرطوبة معطل',
            data: {
                utcTime: '14:00',
                dryTemp: '30.2',
                wetTemp: '#',
                relativeHumidity: '#',
                windDirection: '22',
                windSpeed: '08'
            }
        },
        {
            title: 'مثال 3: أجهزة متعددة معطلة (UTC فقط)',
            description: 'أجهزة الرياح تحت الصيانة',
            data: {
                utcTime: '14:00',
                dryTemp: '18.5',
                wetTemp: '16.2',
                relativeHumidity: '085',
                windDirection: '#',
                windSpeed: '#',
                avgWindDirection: '#',
                avgWindSpeed: '#'
            }
        },
        {
            title: 'مثال 4: معظم الأجهزة معطلة (UTC فقط)',
            description: 'محطة تحت الصيانة الشاملة',
            data: {
                utcTime: '#',
                dryTemp: '#',
                wetTemp: '#',
                relativeHumidity: '#',
                vaporPressure: '#',
                dewPoint: '#',
                windDirection: '#',
                windSpeed: '#'
            }
        }
    ];
    
    let message = '📋 أمثلة على استخدام # للبيانات غير المتوفرة (UTC فقط):\n\n';
    
    examples.forEach((example, index) => {
        message += `${index + 1}. ${example.title}\n`;
        message += `   ${example.description}\n`;
        
        Object.entries(example.data).forEach(([field, value]) => {
            const fieldName = getFieldDisplayName(field);
            message += `   • ${fieldName}: ${value}\n`;
        });
        
        message += '\n';
    });
    
    message += '💡 ملاحظة: # تستخدم عندما تكون البيانات غير متوفرة بسبب:\n';
    message += '   - عطل في الجهاز\n';
    message += '   - صيانة\n';
    message += '   - ظروف جوية تمنع القياس\n';
    message += '   - أي سبب آخر يمنع الحصول على القياس الصحيح\n\n';
    message += '⚠️ يتم استخدام التوقيت العالمي (UTC) فقط في النظام';
    
    alert(message);
}

// إعداد معالجات الأحداث للحقول
function setupFieldHashHandlers() {
    const fields = [
        'utcTime', 'dryTemp', 'wetTemp', 'dewPoint', 'vaporPressure',
        'relativeHumidity', 'windDirection', 'windSpeed',
        'avgWindDirection', 'avgWindSpeed', 'totalCloudCover'
    ];
    
    fields.forEach(fieldId => {
        const input = document.getElementById(fieldId);
        if (input) {
            // إضافة حدث للإدخال
            input.addEventListener('input', function() {
                handleFieldHashInput(fieldId, this.value);
            });
            
            // إضافة حدث للتركيز
            input.addEventListener('focus', function() {
                if (this.value === '#') {
                    this.select();
                }
            });
            
            // إضافة حدث للتغيير
            input.addEventListener('change', function() {
                updateFieldHashStatus(fieldId, this.value);
            });
        }
    });
}

// معالجة إدخال # في الحقل
function handleFieldHashInput(fieldId, value) {
    // إذا كانت القيمة تحتوي على # ولكن ليست فقط #
    if (value.includes('#') && value !== '#') {
        const input = document.getElementById(fieldId);
        if (input) {
            input.value = '#';
            showHashAppliedHint(fieldId);
        }
    }
}

// تحديث حالة الحقل مع #
function updateFieldHashStatus(fieldId, value) {
    const input = document.getElementById(fieldId);
    if (!input) return;
    
    const isMissingData = (value === '#');
    
    // تحديث المظهر
    if (isMissingData) {
        input.classList.add('has-missing-data');
        
        // إخفاء إشارة السالب/الموجب
        const signElement = document.getElementById(fieldId + 'Sign');
        if (signElement) {
            signElement.style.display = 'none';
        }
        
        // تعطيل أزرار السالب/الموجب
        const toggleButtons = document.querySelectorAll(`.sign-toggle[data-target="${fieldId}"]`);
        toggleButtons.forEach(btn => {
            btn.disabled = true;
            btn.classList.add('disabled');
        });
        
        // إظهار تلميحة
        showHashAppliedHint(fieldId);
    } else {
        input.classList.remove('has-missing-data');
        
        // إظهار إشارة السالب/الموجب
        const signElement = document.getElementById(fieldId + 'Sign');
        if (signElement) {
            signElement.style.display = 'block';
        }
        
        // تمكين أزرار السالب/الموجب
        const toggleButtons = document.querySelectorAll(`.sign-toggle[data-target="${fieldId}"]`);
        toggleButtons.forEach(btn => {
            btn.disabled = false;
            btn.classList.remove('disabled');
        });
    }
}

// إظهار تلميحة تطبيق #
function showHashAppliedHint(fieldId) {
    const fieldNames = {
        'utcTime': 'التوقيت العالمي',
        'dryTemp': 'الحرارة الجافة',
        'wetTemp': 'الحرارة الرطبة',
        'relativeHumidity': 'الرطوبة',
        'vaporPressure': 'ضغط البخار',
        'dewPoint': 'درجة الندى',
        'windDirection': 'اتجاه الرياح',
        'windSpeed': 'سرعة الرياح',
        'avgWindDirection': 'متوسط الاتجاه',
        'avgWindSpeed': 'متوسط السرعة',
        'totalCloudCover': 'التغطية السحابية'
    };
    
    const fieldName = fieldNames[fieldId] || fieldId;
    showNotificationSafe(`✅ تم تعيين # لـ ${fieldName} كبيانات غير متوفرة (UTC فقط)`, 'info');
}

// دالة آمنة لإظهار الإشعارات (تجنب التعاود)
function showNotificationSafe(message, type = 'info') {
    // التحقق أولاً إذا كانت هناك دالة showNotification في window
    if (window.showNotification && typeof window.showNotification === 'function' && window.showNotification !== showNotification) {
        try {
            window.showNotification(message, type);
            return;
        } catch (error) {
            console.warn('خطأ في استدعاء showNotification العالمية:', error);
            // استمرار إلى النسخة الاحتياطية
        }
    }
    
    // استخدام نسخة احتياطية
    const notification = document.createElement('div');
    notification.textContent = message;
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        z-index: 9999;
        padding: 12px 20px;
        border-radius: 8px;
        color: white;
        background: ${type === 'success' ? '#28a745' : 
                    type === 'error' ? '#dc3545' : 
                    type === 'warning' ? '#ffc107' : '#17a2b8'};
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        font-family: 'Segoe UI', Arial, sans-serif;
    `;
    
    // إزالة أي إشعارات سابقة
    const existingNotifications = document.querySelectorAll('[data-missing-data-notification]');
    existingNotifications.forEach(el => el.remove());
    
    notification.setAttribute('data-missing-data-notification', 'true');
    document.body.appendChild(notification);
    
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 3000);
}

// دالة مساعدة للحصول على اسم الحقل
function getFieldDisplayName(fieldId) {
    const names = {
        'utcTime': 'التوقيت العالمي (UTC)',
        'dryTemp': 'الحرارة الجافة',
        'wetTemp': 'الحرارة الرطبة',
        'relativeHumidity': 'الرطوبة النسبية',
        'vaporPressure': 'ضغط البخار',
        'dewPoint': 'درجة الندى',
        'windDirection': 'اتجاه الرياح',
        'windSpeed': 'سرعة الرياح',
        'avgWindDirection': 'متوسط الاتجاه',
        'avgWindSpeed': 'متوسط السرعة',
        'totalCloudCover': 'التغطية السحابية'
    };
    
    return names[fieldId] || fieldId;
}

// تهيئة عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(() => {
        initializeMissingDataHandler();
        console.log('✅ تم تحميل معالج البيانات المفقودة (UTC فقط)');
    }, 1500);
});

// جعل الدوال متاحة عالمياً
window.initializeMissingDataHandler = initializeMissingDataHandler;
window.setAllFieldsToMissingData = setAllFieldsToMissingData;
window.showMissingDataExamples = showMissingDataExamples;

console.log('⚠️ تم تحميل معالج البيانات المفقودة (#) (UTC فقط)');