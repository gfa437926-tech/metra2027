// js/fix-form-handler.js - معالج النموذج الخاص بصفحة الأعطال
console.log('🔄 تحميل معالج النموذج...');

class FixFormHandler {
    constructor() {
        this.supabase = null;
        this.currentUser = null;
        this.init();
    }

    async init() {
        await this.initializeSupabase();
        await this.setupEventListeners();
    }

    async initializeSupabase() {
        const SUPABASE_URL = 'https://tmdblguwkdypxfhjeomx.supabase.co';
        const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtZGJsZ3V3a2R5cHhmaGplb214Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY4MzgzMzQsImV4cCI6MjA3MjQxNDMzNH0.I0l4rjVAD24rVybSRtvVH6WAEI8zqzaNX4gKd_pDmIQ';
        
        this.supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    }

    async setupEventListeners() {
        // إعداد معالج إرسال النموذج الرئيسي
        document.getElementById('failureReportForm').addEventListener('submit', (e) => {
            this.handleFormSubmit(e);
        });

        // إعداد معالج النموذج اليدوي
        document.getElementById('submitManualMeasurement').addEventListener('click', () => {
            this.handleManualFormSubmit();
        });

        // إعداد باقي المستمعين للأحداث
        this.setupStationTypeToggle();
        this.setupEquipmentSelection();
        this.setupMeasurementButtons();
    }

    setupStationTypeToggle() {
        document.querySelectorAll('.station-type-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                document.querySelectorAll('.station-type-btn').forEach(b => {
                    b.classList.remove('active');
                });
                this.classList.add('active');
                
                const stationType = this.getAttribute('data-station-type');
                this.toggleStationSections(stationType);
            }.bind(this));
        });
    }

    setupEquipmentSelection() {
        document.querySelectorAll('.equipment-item').forEach(item => {
            item.addEventListener('click', function() {
                document.querySelectorAll('.equipment-item').forEach(i => {
                    i.classList.remove('selected');
                });
                this.classList.add('selected');
            });
        });

        document.querySelectorAll('.equipment-category h6').forEach(header => {
            header.addEventListener('click', function() {
                const targetId = this.getAttribute('data-bs-target').substring(1);
                const target = document.getElementById(targetId);
                target.classList.toggle('show');
                
                const icon = this.querySelector('.fa-chevron-down');
                if (icon) {
                    icon.classList.toggle('fa-chevron-down');
                    icon.classList.toggle('fa-chevron-up');
                }
            });
        });
    }

    setupMeasurementButtons() {
        document.querySelectorAll('.measurement-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                const measurementType = this.getAttribute('data-measurement');
                const measurementName = this.closest('.manual-measurement-card').querySelector('.measurement-title').textContent;
                
                document.getElementById('manualMeasurementType').value = measurementName;
                
                const modal = new bootstrap.Modal(document.getElementById('manualMeasurementModal'));
                modal.show();
            });
        });
    }

    toggleStationSections(stationType) {
        const automaticSection = document.getElementById('automatic-section');
        const manualSection = document.getElementById('manual-section');
        
        if (stationType === 'automatic') {
            automaticSection.style.display = 'block';
            manualSection.style.display = 'none';
        } else {
            automaticSection.style.display = 'none';
            manualSection.style.display = 'block';
        }
    }

    async handleFormSubmit(e) {
        e.preventDefault();
        
        const user = await this.checkLoginStatus();
        if (!user) return;
        
        this.toggleLoading('submit', true);
        
        try {
            const formData = this.collectFormData();
            
            if (!this.validateFormData(formData)) {
                this.toggleLoading('submit', false);
                return;
            }

            await this.submitFailureReport(formData, user);
            
        } catch (error) {
            console.error('❌ خطأ في إرسال النموذج:', error);
            this.showAlert('❌ حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.', 'danger');
        } finally {
            this.toggleLoading('submit', false);
        }
    }

    collectFormData() {
        const stationType = document.getElementById('automatic-station').classList.contains('active') ? 'أوتوماتيكية' : 'يدوية';
        let equipmentType = '';
        
        if (stationType === 'أوتوماتيكية') {
            const selectedEquipment = document.querySelector('.equipment-item.selected');
            equipmentType = selectedEquipment ? selectedEquipment.textContent : '';
        } else {
            equipmentType = document.getElementById('manualMeasurementType').value || 'مقياس يدوي';
        }
        
        return {
            stationType,
            equipmentType,
            failureDescription: document.getElementById('failureDescription').value,
            failureDate: document.getElementById('failureDate').value,
            failureSeverity: document.getElementById('failureSeverity').value,
            urgentRepair: document.getElementById('urgentRepair').checked
        };
    }

    validateFormData(data) {
        if (!data.equipmentType) {
            this.showAlert('❌ يرجى اختيار نوع الجهاز المعطل.', 'danger');
            return false;
        }

        if (!data.failureDescription || data.failureDescription.length < 10) {
            this.showAlert('❌ يرجى إدخال وصف العطل (على الأقل 10 أحرف).', 'danger');
            return false;
        }

        if (!data.failureDate) {
            this.showAlert('❌ يرجى إدخال تاريخ ووقت العطل.', 'danger');
            return false;
        }

        return true;
    }

    async submitFailureReport(formData, user) {
        const equipmentCategory = this.determineEquipmentCategory(formData);
        
        const report = {
            user_id: user.id,
            reporter_name: `${user.first_name} ${user.father_name} ${user.last_name}`,
            station: user.station,
            station_type: formData.stationType,
            equipment_category: equipmentCategory,
            equipment_type: formData.equipmentType,
            failure_description: formData.failureDescription,
            failure_date: formData.failureDate,
            failure_severity: formData.failureSeverity,
            urgent: formData.urgentRepair,
            status: 'معلق',
            created_at: new Date().toISOString()
        };

        const { data, error } = await this.supabase
            .from('equipment_failures')
            .insert([report])
            .select();

        if (error) {
            throw new Error(error.message);
        }

        this.showAlert('✅ تم إرسال البلاغ بنجاح وسيتم معالجته قريباً', 'success');
        this.resetForm();
        await this.loadFailureStats(user.id);
    }

    determineEquipmentCategory(formData) {
        if (formData.stationType === 'يدوية') return 'مقاييس يدوية';
        
        if (formData.equipmentType.includes('لاسلكي') || formData.equipmentType.includes('مودم') || 
            formData.equipmentType.includes('هوائي') || formData.equipmentType.includes('SIM')) {
            return 'أنظمة الاتصالات';
        } else if (formData.equipmentType.includes('طاقة') || formData.equipmentType.includes('شحن') || 
                   formData.equipmentType.includes('بطارية') || formData.equipmentType.includes('محول')) {
            return 'أنظمة الطاقة';
        }
        
        return 'أجهزة الاستشعار';
    }

    async handleManualFormSubmit() {
        const measurementType = document.getElementById('manualMeasurementType').value;
        const measurementBrand = document.getElementById('manualMeasurementBrand').value;
        const measurementProblem = document.getElementById('manualMeasurementProblem').value;
        const measurementDescription = document.getElementById('manualMeasurementDescription').value;
        const measurementUrgent = document.getElementById('manualMeasurementUrgent').checked;

        if (!measurementBrand || !measurementProblem || !measurementDescription) {
            this.showAlert('❌ يرجى ملء جميع الحقول المطلوبة.', 'danger');
            return;
        }

        // إضافة وصف المقياس والعلامة التجارية إلى وصف العطل
        const fullDescription = `نوع المقياس: ${measurementType}\nالعلامة التجارية: ${measurementBrand}\nنوع المشكلة: ${measurementProblem}\nوصف العطل: ${measurementDescription}`;
        
        document.getElementById('failureDescription').value = fullDescription;
        document.getElementById('urgentRepair').checked = measurementUrgent;
        
        // إغلاق النموذج
        bootstrap.Modal.getInstance(document.getElementById('manualMeasurementModal')).hide();
        
        this.showAlert('✅ تم تعبئة بيانات العطل، يرجى إكمال باقي الحقول وإرسال البلاغ', 'info');
    }

    resetForm() {
        document.getElementById('failureReportForm').reset();
        document.querySelectorAll('.equipment-item').forEach(item => {
            item.classList.remove('selected');
        });
        if (document.querySelector('.equipment-item')) {
            document.querySelector('.equipment-item').classList.add('selected');
        }
        
        // تعيين التاريخ الحالي
        const now = new Date();
        now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
        document.getElementById('failureDate').value = now.toISOString().slice(0, 16);
        
        // إعادة تعيين النموذج اليدوي
        document.getElementById('manualMeasurementForm').reset();
    }

    async checkLoginStatus() {
        try {
            const userData = localStorage.getItem('currentUser');
            
            if (!userData) {
                window.location.href = 'index.html';
                return null;
            }
            
            const user = JSON.parse(userData);
            
            // جلب البيانات المحدثة من قاعدة البيانات
            const { data: userProfile, error } = await this.supabase
                .from('users')
                .select('*')
                .eq('id', user.id)
                .single();
                
            if (error) {
                console.error('❌ خطأ في جلب بيانات المستخدم:', error);
                return user;
            }
            
            return userProfile || user;
            
        } catch (error) {
            console.error('❌ خطأ في التحقق من حالة الدخول:', error);
            localStorage.removeItem('currentUser');
            window.location.href = 'index.html';
            return null;
        }
    }

    async loadFailureStats(userId) {
        try {
            const { data, error } = await this.supabase
                .from('equipment_failures')
                .select('status, urgent')
                .eq('user_id', userId);
            
            if (error) {
                console.error('Error loading stats:', error);
                return;
            }
            
            let pendingCount = 0;
            let reviewCount = 0;
            let resolvedCount = 0;
            let urgentCount = 0;
            
            if (data) {
                data.forEach(failure => {
                    if (failure.status === 'معلق') pendingCount++;
                    if (failure.status === 'قيد المراجعة') reviewCount++;
                    if (failure.status === 'تم الإصلاح') resolvedCount++;
                    if (failure.urgent) urgentCount++;
                });
            }
            
            document.getElementById('pendingCount').textContent = pendingCount;
            document.getElementById('reviewCount').textContent = reviewCount;
            document.getElementById('resolvedCount').textContent = resolvedCount;
            document.getElementById('urgentCount').textContent = urgentCount;
            
        } catch (error) {
            console.error('Error loading failure stats:', error);
        }
    }

    toggleLoading(buttonId, isLoading) {
        const button = document.getElementById(buttonId);
        const loading = document.getElementById(buttonId + 'Loading');
        
        if (button) button.disabled = isLoading;
        if (loading) loading.style.display = isLoading ? 'inline-block' : 'none';
    }

    showAlert(message, type = 'info') {
        const existingAlerts = document.querySelectorAll('.custom-alert');
        existingAlerts.forEach(alert => alert.remove());
        
        const alertDiv = document.createElement('div');
        alertDiv.className = `custom-alert alert alert-${type} alert-dismissible fade show`;
        alertDiv.style.position = 'fixed';
        alertDiv.style.top = '20px';
        alertDiv.style.right = '20px';
        alertDiv.style.zIndex = '9999';
        alertDiv.style.minWidth = '300px';
        alertDiv.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        document.body.appendChild(alertDiv);
        
        setTimeout(() => {
            if (alertDiv.parentNode) alertDiv.remove();
        }, 5000);
    }
}

// جعل الفصل متاحاً عالمياً
window.FixFormHandler = FixFormHandler;