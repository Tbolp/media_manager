import { create } from 'zustand';

interface UploadEntry {
  fileName: string;
  progress: number;
  status: 'uploading' | 'success' | 'failed' | 'cancelled';
  abortController?: AbortController;
}

interface UploadState {
  uploads: Record<string, UploadEntry>;
  startUpload: (libraryId: string, fileName: string, ac: AbortController) => void;
  updateProgress: (libraryId: string, progress: number) => void;
  finishUpload: (libraryId: string, status: 'success' | 'failed') => void;
  cancelUpload: (libraryId: string) => void;
  clearUpload: (libraryId: string) => void;
}

export const useUploadStore = create<UploadState>()((set, get) => ({
  uploads: {},

  startUpload: (libraryId, fileName, ac) =>
    set((state) => ({
      uploads: {
        ...state.uploads,
        [libraryId]: { fileName, progress: 0, status: 'uploading', abortController: ac },
      },
    })),

  updateProgress: (libraryId, progress) =>
    set((state) => {
      const entry = state.uploads[libraryId];
      if (!entry) return state;
      return {
        uploads: { ...state.uploads, [libraryId]: { ...entry, progress } },
      };
    }),

  finishUpload: (libraryId, status) =>
    set((state) => {
      const entry = state.uploads[libraryId];
      if (!entry) return state;
      return {
        uploads: {
          ...state.uploads,
          [libraryId]: { ...entry, status, abortController: undefined },
        },
      };
    }),

  cancelUpload: (libraryId) => {
    const entry = get().uploads[libraryId];
    if (entry?.abortController) {
      entry.abortController.abort();
    }
    set((state) => {
      const current = state.uploads[libraryId];
      if (!current) return state;
      return {
        uploads: {
          ...state.uploads,
          [libraryId]: { ...current, status: 'cancelled', abortController: undefined },
        },
      };
    });
  },

  clearUpload: (libraryId) =>
    set((state) => {
      const { [libraryId]: _, ...rest } = state.uploads;
      void _;
      return { uploads: rest };
    }),
}));
