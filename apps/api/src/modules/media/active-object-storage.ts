import { Injectable } from '@nestjs/common';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import type { ObjectStorage, PresignedPut, StoredObjectInfo } from './object-storage.js';

/**
 * The production `OBJECT_STORAGE` (v1.75-social, D222, §10.72): every call goes to the storage of the settings in
 * force now — the panel's «التخزين (R2 / S3)» when it is on, else the server's `S3_*` — so a change in the panel needs
 * no restart. Each call takes the storage once: a call already running finishes on the client it started with.
 */
@Injectable()
export class ActiveObjectStorage implements ObjectStorage {
  constructor(private readonly store: StorageSettingsStore) {}

  async presignPut(
    key: string,
    contentType: string,
    contentLength: number,
    expiresInSeconds: number,
  ): Promise<PresignedPut> {
    return (await this.store.active()).presignPut(key, contentType, contentLength, expiresInSeconds);
  }

  async head(key: string): Promise<StoredObjectInfo | null> {
    return (await this.store.active()).head(key);
  }

  async get(key: string, maxBytes: number): Promise<Buffer | null> {
    return (await this.store.active()).get(key, maxBytes);
  }

  async put(key: string, body: Buffer, contentType: string, cacheControl: string): Promise<void> {
    return (await this.store.active()).put(key, body, contentType, cacheControl);
  }

  async getRange(key: string, offset: number, length: number): Promise<Buffer | null> {
    return (await this.store.active()).getRange(key, offset, length);
  }

  async copy(fromKey: string, toKey: string, contentType: string, cacheControl: string): Promise<void> {
    return (await this.store.active()).copy(fromKey, toKey, contentType, cacheControl);
  }

  async delete(keys: readonly string[]): Promise<void> {
    return (await this.store.active()).delete(keys);
  }
}
