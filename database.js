// database.js - نظام إدارة قاعدة البيانات
console.log('🗃️ تحميل نظام إدارة قاعدة البيانات...');

class DatabaseManager {
    constructor() {
        this.supabase = null;
        this.initializeSupabase();
    }

    initializeSupabase() {
        try {
            if (window.supabase && window.CONFIG?.SUPABASE?.url && window.CONFIG?.SUPABASE?.anonKey) {
                this.supabase = window.supabase.createClient(
                    window.CONFIG.SUPABASE.url, 
                    window.CONFIG.SUPABASE.anonKey,
                    {
                        auth: {
                            autoRefreshToken: true,
                            persistSession: true,
                            detectSessionInUrl: true
                        }
                    }
                );
                console.log('✅ تم تهيئة Supabase بنجاح');
            } else {
                console.error('❌ إعدادات Supabase غير مكتملة');
            }
        } catch (error) {
            console.error('❌ فشل في تهيئة Supabase:', error);
        }
    }

    // إرسال بلاغ عطل جديد
    async submitFailureReport(failureData, user) {
        try {
            console.log('📤 بدء إرسال بلاغ العطل:', failureData);

            // التحقق من اتصال Supabase
            if (!this.supabase) {
                throw new Error('اتصال قاعدة البيانات غير متوفر');
            }

            // التحقق من البيانات
            const validation = this.validateFailureData(failureData);
            if (!validation.isValid) {
                throw new Error(validation.message);
            }

            // إعداد بيانات الإرسال
            const submissionData = this.prepareSubmissionData(failureData, user);
            console.log('📝 بيانات الإرسال المعدلة:', submissionData);

            // الإرسال إلى Supabase
            const { data, error } = await this.supabase
                .from('telecom_failures')
                .insert([submissionData])
                .select();

            if (error) {
                console.error('❌ خطأ في الإرسال:', error);
                throw new Error(this.getErrorMessage(error));
            }

            console.log('✅ تم الإرسال بنجاح:', data);

            return {
                success: true,
                data: data[0],
                message: 'تم إرسال البلاغ بنجاح!'
            };

        } catch (error) {
            console.error('❌ خطأ في إرسال البلاغ:', error);
            return {
                success: false,
                message: error.message
            };
        }
    }

    // إعداد بيانات الإرسال
    prepareSubmissionData(failureData, user) {
        const baseData = {
            device_type: failureData.device_type,
            problem_type: failureData.problemType,
            description: failureData.description,
            urgent: failureData.urgent || false,
            
            station: user.station,
            reporter_name: `${user.first_name} ${user.father_name} ${user.last_name}`,
            reporter_id: user.id,
            reporter_email: user.email,
            reporter_phone: user.phone,
            
            status: 'معلق',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };

        // إضافة الحقول الخاصة بكل نوع جهاز
        switch (failureData.device_type) {
            case 'phone':
                baseData.phone_type = failureData.phoneType;
                baseData.phone_brand = failureData.phoneBrand;
                break;
                
            case 'tower':
                baseData.tower_type = failureData.towerType;
                baseData.tower_height = failureData.towerHeight;
                break;
                
            case 'satellite':
                baseData.satellite_type = failureData.satelliteType;
                baseData.satellite_brand = failureData.satelliteBrand;
                break;
                
            case 'fax':
                baseData.fax_type = failureData.faxType;
                baseData.fax_brand = failureData.faxBrand;
                break;
                
            case 'computer':
                baseData.computer_type = failureData.computerType;
                baseData.computer_brand = failureData.computerBrand;
                break;
                
            case 'laptop':
                baseData.laptop_type = failureData.laptopType;
                baseData.laptop_brand = failureData.laptopBrand;
                break;
                
            case 'printer':
                baseData.printer_type = failureData.printerType;
                baseData.printer_brand = failureData.printerBrand;
                break;
                
            case 'network':
                baseData.network_type = failureData.networkType;
                baseData.network_device = failureData.networkDevice;
                break;
                
            case 'wifi':
                baseData.wifi_type = failureData.wifiType;
                baseData.wifi_brand = failureData.wifiBrand;
                break;
        }

        return baseData;
    }

    // التحقق من البيانات
    validateFailureData(data) {
        const requiredFields = [];

        // الحقول العامة المطلوبة
        if (!data.device_type) requiredFields.push('نوع الجهاز');
        if (!data.problemType) requiredFields.push('نوع العطل');
        if (!data.description || data.description.length < 10) {
            return {
                isValid: false,
                message: 'وصف العطل يجب أن يكون على الأقل 10 أحرف'
            };
        }

        // الحقول الخاصة بكل جهاز
        switch (data.device_type) {
            case 'phone':
                if (!data.phoneType) requiredFields.push('نوع الهاتف');
                if (!data.phoneBrand) requiredFields.push('علامة الهاتف التجارية');
                break;
                
            case 'tower':
                if (!data.towerType) requiredFields.push('نوع البرج');
                if (!data.towerHeight) requiredFields.push('ارتفاع البرج');
                break;
                
            case 'computer':
                if (!data.computerType) requiredFields.push('نوع الكمبيوتر');
                if (!data.computerBrand) requiredFields.push('علامة الكمبيوتر التجارية');
                break;
                
            case 'printer':
                if (!data.printerType) requiredFields.push('نوع الطابعة');
                if (!data.printerBrand) requiredFields.push('علامة الطابعة التجارية');
                break;
        }

        if (requiredFields.length > 0) {
            return {
                isValid: false,
                message: `الحقول التالية مطلوبة: ${requiredFields.join('، ')}`
            };
        }

        return { isValid: true, message: '' };
    }

    // جلب الأعطال السابقة
    async getPreviousFailures(userId = null) {
        try {
            if (!this.supabase) {
                throw new Error('اتصال قاعدة البيانات غير متوفر');
            }

            let query = this.supabase
                .from('telecom_failures')
                .select('*')
                .order('created_at', { ascending: false });

            if (userId) {
                query = query.eq('reporter_id', userId);
            }

            const { data, error } = await query;

            if (error) {
                console.error('❌ خطأ في جلب البيانات:', error);
                throw new Error(this.getErrorMessage(error));
            }

            return {
                success: true,
                data: data || []
            };

        } catch (error) {
            console.error('❌ خطأ في جلب الأعطال:', error);
            return {
                success: false,
                error: error.message,
                data: []
            };
        }
    }

    // جلب الإحصائيات
    async getFailureStats(userId = null) {
        try {
            if (!this.supabase) {
                throw new Error('اتصال قاعدة البيانات غير متوفر');
            }

            let query = this.supabase
                .from('telecom_failures')
                .select('status, urgent');

            if (userId) {
                query = query.eq('reporter_id', userId);
            }

            const { data, error } = await query;

            if (error) {
                console.error('❌ خطأ في جلب الإحصائيات:', error);
                throw new Error(this.getErrorMessage(error));
            }

            return {
                success: true,
                data: data || []
            };

        } catch (error) {
            console.error('❌ خطأ في جلب الإحصائيات:', error);
            return {
                success: false,
                error: error.message,
                data: []
            };
        }
    }

    // تحديث حالة البلاغ
    async updateFailureStatus(failureId, status, notes = '') {
        try {
            if (!this.supabase) {
                throw new Error('اتصال قاعدة البيانات غير متوفر');
            }

            const { data, error } = await this.supabase
                .from('telecom_failures')
                .update({
                    status: status,
                    technician_notes: notes,
                    updated_at: new Date().toISOString()
                })
                .eq('id', failureId)
                .select();

            if (error) {
                console.error('❌ خطأ في تحديث الحالة:', error);
                throw new Error(this.getErrorMessage(error));
            }

            return {
                success: true,
                data: data[0]
            };

        } catch (error) {
            console.error('❌ خطأ في تحديث الحالة:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // اختبار الاتصال بقاعدة البيانات
    async testConnection() {
        try {
            if (!this.supabase) {
                console.error('❌ Supabase غير مهيئ');
                return false;
            }

            const { data, error } = await this.supabase
                .from('telecom_failures')
                .select('count')
                .limit(1);

            if (error) {
                console.error('❌ فشل اختبار الاتصال:', error);
                return false;
            }

            console.log('✅ اختبار الاتصال بنجاح');
            return true;

        } catch (error) {
            console.error('❌ خطأ في اختبار الاتصال:', error);
            return false;
        }
    }

    // تحويل أخطاء Supabase إلى رسائل مفهومة
    getErrorMessage(error) {
        const errorMessages = {
            '23505': 'هذا البلاغ مسجل مسبقاً',
            '42501': 'ليس لديك صلاحية للقيام بهذا الإجراء',
            '42P01': 'جدول البيانات غير موجود',
            '08006': 'فشل في الاتصال بقاعدة البيانات',
            'default': 'حدث خطأ غير متوقع في قاعدة البيانات'
        };

        return errorMessages[error.code] || error.message || errorMessages['default'];
    }

    // تصدير البيانات
    async exportData(format = 'json', userId = null) {
        try {
            if (!this.supabase) {
                throw new Error('اتصال قاعدة البيانات غير متوفر');
            }

            let query = this.supabase
                .from('telecom_failures')
                .select('*');

            if (userId) {
                query = query.eq('reporter_id', userId);
            }

            const { data, error } = await query;

            if (error) {
                throw new Error(this.getErrorMessage(error));
            }

            let exportedData;
            switch (format) {
                case 'json':
                    exportedData = JSON.stringify(data, null, 2);
                    break;
                case 'csv':
                    exportedData = this.convertToCSV(data);
                    break;
                default:
                    exportedData = data;
            }

            return {
                success: true,
                data: exportedData,
                format: format
            };

        } catch (error) {
            console.error('❌ خطأ في تصدير البيانات:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // تحويل البيانات إلى CSV
    convertToCSV(data) {
        if (!data || data.length === 0) return '';
        
        const headers = Object.keys(data[0]);
        const csvRows = [headers.join(',')];
        
        for (const row of data) {
            const values = headers.map(header => {
                const escaped = ('' + row[header]).replace(/"/g, '""');
                return `"${escaped}"`;
            });
            csvRows.push(values.join(','));
        }
        
        return csvRows.join('\n');
    }
}

// إنشاء نسخة عامة من مدير قاعدة البيانات
window.database = new DatabaseManager();
console.log('✅ تم تحميل نظام إدارة قاعدة البيانات بنجاح');