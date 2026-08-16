import 'package:equatable/equatable.dart';

/// Wrapper genérico para estado asíncrono en providers: evita repetir
/// `isLoading` + `errorMessage` + `data` sueltos en cada provider y hace que
/// las screens manejen los 4 casos (idle/loading/data/error) de forma
/// uniforme.
sealed class UiState<T> extends Equatable {
  const UiState();
}

class UiIdle<T> extends UiState<T> {
  const UiIdle();

  @override
  List<Object?> get props => [];
}

class UiLoading<T> extends UiState<T> {
  const UiLoading();

  @override
  List<Object?> get props => [];
}

class UiData<T> extends UiState<T> {
  final T data;
  const UiData(this.data);

  @override
  List<Object?> get props => [data];
}

class UiError<T> extends UiState<T> {
  final String message;
  const UiError(this.message);

  @override
  List<Object?> get props => [message];
}
