// js/rainfall-send.js
console.log('🌧️ تحميل نظام إرسال النشرات المطرية...');

class RainfallDataSender {
    constructor() {
        this.supabase = window.supabase || null;
        this.isDemoMode = false;
        this.observerInfo = this.loadObserverInfo();
        console.log('📡 تم تهيئة نظام الإرسال:', {
            hasSupabase: !!this.supabase,
            observer: this.observerInfo
        });
    }

    // تحميل معلومات الراصد
    loadObserverInfo() {
        try {
            const userData = localStorage.getItem('currentUser');
            if (userData) {
                const user = JSON.parse(userData);
                return {
                    name: user.name || user.username || 'الراصد الجوي',
                    station: user.station || 'المحطة الرئيسية',
                    jobTitle: user.role || user.jobTitle || 'الراصد الجوي',
                    userId: user.id || 'unknown'
                };
            }
        } catch (error) {
            console.error('❌ خطأ في تحميل معلومات الراصد:', error);
        }
        
        return {
            name: 'الراصد الجوي',
            station: 'المحطة الرئيسية',
            jobTitle: 'الراصد الجوي',
            userId: 'unknown'
        };
    }

    // التحقق من صحة البيانات مع دعم #
    validateRainfallData(formData) {
        const errors = [];

        // التحقق من كمية الهطول (تسمح بـ #)
        const rainAmount = formData.rain_amount;
        if (rainAmount !== '#') {
            const rainAmountNum = parseFloat(rainAmount);
            if (isNaN(rainAmountNum) || rainAmountNum < 0 || rainAmountNum > 999.9) {
                errors.push('كمية الهطول يجب أن تكون بين 0 و 999.9 ملم أو # لعدم التوفر');
            } else if (!/^\d{3}\.\d$/.test(rainAmount)) {
                errors.push('تنسيق كمية الهطول يجب أن يكون ###.#');
            }
        }

        // التحقق من سماكة الثلوج (تسمح بـ #)
        const snowDepth = formData.snow_depth;
        if (snowDepth !== '#') {
            const snowDepthNum = parseInt(snowDepth);
            if (isNaN(snowDepthNum) || snowDepthNum < 0 || snowDepthNum > 999) {
                errors.push('سماكة الثلوج يجب أن تكون بين 0 و 999 سم أو # لعدم التوفر');
            } else if (!/^\d{3}$/.test(snowDepth)) {
                errors.push('تنسيق سماكة الثلوج يجب أن يكون ###');
            }
        }

        // التحقق من تاريخ الرصد
        if (!formData.observation_date) {
            errors.push('يجب تحديد تاريخ الرصد');
        }

        // التحقق من الوقت المحلي
        if (!formData.local_time) {
            errors.push('يجب اختيار الوقت المحلي');
        } else {
            // التحقق من أن الوقت بين 8:30 و 9:30
            const [hours, minutes] = formData.local_time.split(':');
            const totalMinutes = parseInt(hours) * 60 + parseInt(minutes);
            const minTime = 8 * 60 + 30; // 8:30
            const maxTime = 9 * 60 + 30; // 9:30
            
            if (totalMinutes < minTime || totalMinutes > maxTime) {
                errors.push('وقت النشرة يجب أن يكون بين 08:30 و 09:30 صباحاً');
            }
        }

        return {
            isValid: errors.length === 0,
            errors: errors
        };
    }

    // تجهيز البيانات للإرسال مع دعم #
    prepareRainfallData(formData) {
        const now = new Date().toISOString();
        const observationDay = new Date(formData.observation_date).getDate();
        
        // معالجة البيانات مع دعم #
        const rainAmount = formData.rain_amount === '#' ? null : parseFloat(formData.rain_amount);
        const snowDepth = formData.snow_depth === '#' ? null : parseFloat(formData.snow_depth);
        
        // إضافة معلومات المتصفح
        const browserInfo = this.getBrowserInfo();
        
        return {
            // بيانات المحطة
            station_arabic: this.observerInfo.station,
            station_english: this.observerInfo.station,
            station_type: 'synoptic',
            observation_day: observationDay,
            
            // بيانات الهطول
            rain_amount: rainAmount,
            snow_depth: snowDepth,
            rain_amount_raw: formData.rain_amount,
            snow_depth_raw: formData.snow_depth,
            has_no_data: formData.rain_amount === '#' || formData.snow_depth === '#',
            
            // بيانات الراصد
            observer_name: this.observerInfo.name,
            observer_station: this.observerInfo.station,
            observer_job_title: this.observerInfo.jobTitle,
            observer_id: this.observerInfo.userId,
            
            // بيانات الوقت والتاريخ (تنسيق ميلادي)
            observation_date: formData.observation_date, // YYYY-MM-DD
            local_time: formData.local_time,
            utc_time: formData.utc_time || this.calculateUTCTime(formData.local_time),
            
            // بيانات النظام
            created_at: now,
            updated_at: now,
            status: 'submitted',
            is_demo: this.isDemoMode,
            
            // بيانات المسؤولية
            responsibility_accepted: true,
            submitted_at: now,
            submission_time_window: '08:30-09:30',
            
            // معلومات إضافية
            client_ip: browserInfo.ip,
            user_agent: browserInfo.userAgent,
            browser_language: browserInfo.language,
            
            // معلومات المشاركة
            whatsapp_shared: false,
            whatsapp_share_time: null
        };
    }

    // حساب التوقيت العالمي
    calculateUTCTime(localTime) {
        try {
            if (!localTime) return null;
            
            const [hours, minutes] = localTime.split(':');
            let utcHours = parseInt(hours) - 3; // سوريا +3 من UTC
            
            if (utcHours < 0) {
                utcHours += 24;
            }
            
            return `${String(utcHours).padStart(2, '0')}:${minutes}`;
        } catch (error) {
            console.error('❌ خطأ في حساب UTC:', error);
            return null;
        }
    }

    // جمع معلومات المتصفح
    getBrowserInfo() {
        return {
            userAgent: navigator.userAgent,
            language: navigator.language,
            ip: 'unknown'
        };
    }

    // إرسال البيانات إلى قاعدة البيانات
    async sendRainfallData(formData) {
        try {
            console.log('🌧️ بدء إرسال بيانات النشرة المطرية...', formData);

            // التحقق من صحة البيانات
            const validation = this.validateRainfallData(formData);
            if (!validation.isValid) {
                throw new Error(validation.errors.join('، '));
            }

            // تجهيز البيانات
            const preparedData = this.prepareRainfallData(formData);
            console.log('📦 البيانات المجهزة للإرسال:', preparedData);

            // عرض شاشة التحميل
            this.showLoading(true);

            // في وضع التجربة، حفظ في localStorage فقط
            if (this.isDemoMode || !this.supabase) {
                console.log('🎯 وضع التجربة - حفظ البيانات محلياً');
                const result = this.saveToLocalStorage(preparedData);
                this.showLoading(false);
                return result;
            }

            // إرسال البيانات إلى Supabase
            console.log('🚀 إرسال البيانات إلى Supabase...');
            const { data, error } = await this.supabase
                .from('rainfall_reports')
                .insert([preparedData])
                .select();

            this.showLoading(false);

            if (error) {
                console.error('❌ خطأ في إرسال البيانات إلى Supabase:', error);
                throw new Error(`فشل في إرسال البيانات: ${error.message}`);
            }

            console.log('✅ تم إرسال البيانات بنجاح:', data);
            return {
                success: true,
                data: data[0],
                message: 'تم إرسال النشرة المطرية بنجاح إلى قاعدة البيانات'
            };

        } catch (error) {
            console.error('❌ خطأ في إرسال بيانات النشرة المطرية:', error);
            this.showLoading(false);
            return {
                success: false,
                error: error.message,
                message: `فشل في إرسال البيانات: ${error.message}`
            };
        }
    }

    // حفظ البيانات في localStorage (لوضع التجربة)
    saveToLocalStorage(data) {
        try {
            const storedData = JSON.parse(localStorage.getItem('rainfall_reports_demo') || '[]');
            data.id = `demo-${Date.now()}`;
            data.demo_id = data.id;
            storedData.push(data);
            
            localStorage.setItem('rainfall_reports_demo', JSON.stringify(storedData));
            
            console.log('💾 تم حفظ البيانات محلياً:', data);
            return {
                success: true,
                data: data,
                message: 'تم حفظ النشرة المطرية محلياً (وضع التجربة)'
            };
        } catch (error) {
            console.error('❌ خطأ في حفظ البيانات محلياً:', error);
            throw new Error('فشل في حفظ البيانات محلياً');
        }
    }

    // عرض/إخفاء شاشة التحميل
    showLoading(show) {
        const loadingOverlay = document.getElementById('loadingOverlay');
        if (loadingOverlay) {
            loadingOverlay.style.display = show ? 'flex' : 'none';
        }
    }

    // تحديث حالة المشاركة بالواتساب
    async updateWhatsAppShareStatus(reportId) {
        if (this.isDemoMode || !this.supabase) return;
        
        try {
            const { error } = await this.supabase
                .from('rainfall_reports')
                .update({
                    whatsapp_shared: true,
                    whatsapp_share_time: new Date().toISOString()
                })
                .eq('id', reportId);
                
            if (error) {
                console.error('❌ خطأ في تحديث حالة المشاركة:', error);
            }
        } catch (error) {
            console.error('❌ خطأ في تحديث حالة المشاركة:', error);
        }
    }
}

// إنشاء نسخة عامة للاستخدام
window.rainfallDataSender = new RainfallDataSender();

// دالة مساعدة للإرسال السريع
window.sendRainfallReport = async function(formData) {
    return await window.rainfallDataSender.sendRainfallData(formData);
};

// دالة مشاركة عبر الواتساب مع التاريخ الميلادي
window.shareRainfallReportViaWhatsApp = function(formData) {
    // تنسيق التاريخ بالأرقام الميلادية
    let formattedDate = formData.observation_date; // بالفعل YYYY-MM-DD
    
    // يمكنك اختيار تنسيق مختلف:
    // formattedDate = formatDate(formData.observation_date, 'slash'); // DD/MM/YYYY
    // formattedDate = formatDate(formData.observation_date, 'dash'); // DD-MM-YYYY
    
    // بناء رسالة الواتساب
    let message = `*📊 النشرة المطرية*\n\n`;
    message += `*👤 الراصد:* ${formData.observer_name}\n`;
    message += `*📍 المحطة:* ${formData.station_name}\n`;
    message += `*📅 تاريخ الرصد:* ${formattedDate}\n`;
    message += `*⏰ وقت النشرة:* ${formData.local_time}\n\n`;
    message += `*🌧️ كمية الهطول:* ${formData.rain_amount === '#' ? 'غير متوفرة' : formData.rain_amount + ' مم'}\n`;
    message += `*❄️ سماكة الثلوج:* ${formData.snow_depth === '#' ? 'غير متوفرة' : formData.snow_depth + ' سم'}\n\n`;
    message += `_نظام إدارة البيانات الجوية_\n`;
    message += `_رابط النظام: ${window.location.origin}_`;
    
    const encodedMessage = encodeURIComponent(message);
    const whatsappURL = `https://wa.me/?text=${encodedMessage}`;
    
    window.open(whatsappURL, '_blank');
    
    // تحديث حالة المشاركة إذا كان هناك معرف تقرير
    if (window.rainfallDataSender && formData.reportId) {
        window.rainfallDataSender.updateWhatsAppShareStatus(formData.reportId);
    }
    
    return whatsappURL;
};

// دالة مساعدة لتحويل التاريخ إلى تنسيقات مختلفة
function formatDate(dateString, format = 'iso') {
    try {
        const dateObj = new Date(dateString);
        
        switch(format) {
            case 'iso': // YYYY-MM-DD (التنسيق القياسي)
                return dateObj.toISOString().split('T')[0];
                
            case 'slash': // DD/MM/YYYY
                return `${dateObj.getDate().toString().padStart(2, '0')}/${(dateObj.getMonth() + 1).toString().padStart(2, '0')}/${dateObj.getFullYear()}`;
                
            case 'dash': // DD-MM-YYYY
                return `${dateObj.getDate().toString().padStart(2, '0')}-${(dateObj.getMonth() + 1).toString().padStart(2, '0')}-${dateObj.getFullYear()}`;
                
            case 'full': // يوم، شهر، سنة بالكلمات
                return dateObj.toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                });
                
            default:
                return dateString;
        }
    } catch (error) {
        return dateString;
    }
}

console.log('🌧️ تم تحميل نظام إرسال النشرات المطرية بنجاح');