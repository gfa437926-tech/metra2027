import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, OnInit, Output, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { ObservationApiService, StationDirectoryItem } from '../api/observation-api.service';
import { StationContextService } from './station-context.service';

/**
 * Explicit station selection for station-scoped screens.
 * Does not invent a station: lists catalogue rows the API returns for the signed-in user path.
 */
@Component({
  selector: 'metra-station-picker',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <section class="picker" dir="rtl">
      <label>
        <span>المحطة التشغيلية</span>
        <select
          [ngModel]="stationId"
          (ngModelChange)="onSelect($event)"
          [disabled]="loading || stations.length === 0">
          <option value="">{{ loading ? 'جارٍ تحميل المحطات…' : 'اختر محطة مصرّح بها' }}</option>
          <option *ngFor="let s of stations" [value]="s.id">
            {{ s.name_ar }} <ng-container *ngIf="s.local_station_code">({{ s.local_station_code }})</ng-container>
          </option>
        </select>
      </label>
      <p class="hint" *ngIf="!loading && stations.length === 0">
        لا توجد محطات متاحة من دليل API. تحقق من تسجيل الدخول وصلاحيات الكتالوج.
      </p>
      <p class="hint error" *ngIf="error">{{ error }}</p>
    </section>
  `,
  styles: [`
    .picker{background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:.85rem 1rem;margin-bottom:1rem}
    label{display:grid;gap:.35rem;font-weight:700}
    select{font:inherit;padding:.5rem .65rem;border-radius:8px;border:1px solid #cbd5e1;max-width:100%}
    .hint{margin:.4rem 0 0;color:#64748b;font-size:.9rem}
    .hint.error{color:#991b1b}
  `]
})
export class StationPickerComponent implements OnInit {
  private readonly api = inject(ObservationApiService);
  private readonly stationContext = inject(StationContextService);
  private readonly router = inject(Router);

  @Input() stationId = '';
  @Output() stationIdChange = new EventEmitter<string>();

  stations: StationDirectoryItem[] = [];
  loading = false;
  error = '';

  ngOnInit(): void {
    void this.loadStations();
  }

  async loadStations(): Promise<void> {
    if (!this.api.isConfigured) {
      this.error = 'يلزم ضبط عنوان API وتسجيل الدخول قبل اختيار المحطة.';
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      this.stations = await this.api.getStations(200, 0);
      if (this.stationId && !this.stations.some((s) => s.id === this.stationId)) {
        // Keep explicit UUID from query even if not in the first page; do not clear it.
      }
    } catch (e: unknown) {
      this.stations = [];
      this.error = e instanceof Error ? e.message : 'تعذر تحميل دليل المحطات.';
    } finally {
      this.loading = false;
    }
  }

  onSelect(stationId: string): void {
    if (!stationId) {
      this.stationIdChange.emit('');
      return;
    }
    if (!this.stationContext.isUuid(stationId)) {
      this.error = 'معرّف المحطة غير صالح.';
      return;
    }
    this.stationContext.remember(stationId);
    this.stationIdChange.emit(stationId);
    void this.router.navigate([], {
      queryParams: { stationId },
      queryParamsHandling: 'merge',
    });
  }
}
