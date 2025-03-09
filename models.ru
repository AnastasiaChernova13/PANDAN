from django.db import models

class File(models.Model):
    """
    Модель для хранения информации о файлах.

    Атрибуты:
    - path (str): Путь к файлу.
    - size (int): Размер файла в байтах.
    - extension (str): Расширение файла.
    - scanned_at (datetime): Время сканирования файла.
    """

    path = models.CharField(max_length=255)
    size = models.BigIntegerField()
    extension = models.CharField(max_length=10)
    scanned_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        """
        Возвращает строковое представление объекта.

        :return: Путь к файлу.
        :rtype: str
        """
        return self.path

class Image(models.Model):
    """
    Модель для хранения информации об изображениях.

    Атрибуты:
    - file (File): Связанный файл.
    - width (int): Ширина изображения в пикселях.
    - height (int): Высота изображения в пикселях.
    """

    file = models.OneToOneField(File, on_delete=models.CASCADE)
    width = models.IntegerField()
    height = models.IntegerField()

    @property
    def area(self):
        """
        Возвращает произведение ширины и высоты изображения.

        :return: Площадь изображения.
        :rtype: int
        """
        return self.width * self.height

    def __str__(self):
        """
        Возвращает строковое представление объекта.

        :return: Информация об изображении.
        :rtype: str
        """
        return f"{self.file.path}: {self.width}x{self.height}"

class Document(models.Model):
    """
    Модель для хранения информации о документах.

    Атрибуты:
    - file (File): Связанный файл.
    - pages (int): Количество страниц в документе.
    """

    file = models.OneToOneField(File, on_delete=models.CASCADE)
    pages = models.IntegerField()

    def __str__(self):
        """
        Возвращает строковое представление объекта.

        :return: Информация о документе.
        :rtype: str
        """
        return f"{self.file.path}: {self.pages} pages"

from django.shortcuts import render
from .models import File, Image, Document
import os
import magic
import subprocess

def index(request):
    """
    Основная страница проекта.

    :param request: HTTP-запрос.
    :return: Рендеринг основной страницы.
    """
    if request.method == 'POST':
        directory = request.POST.get('directory')
        scan_directory(directory)
    
    total_size = sum(file.size for file in File.objects.all())
    context = {
        'total_size': total_size / (1024 ** 3),
    }
    return render(request, 'index.html', context)

def statistics(request):
    """
    Статистика файлов по расширениям.

    :param request: HTTP-запрос.
    :return: Рендеринг страницы статистики.
    """
    extensions = File.objects.values_list('extension', flat=True).distinct().order_by('extension')
    extension_count = {}
    for ext in extensions:
        files = File.objects.filter(extension=ext)
        extension_count[ext] = len(files)
    context = {
        'extensions': sorted(extension_count.items(), key=lambda item: item[1], reverse=True),
    }
    return render(request, 'statistics.html', context)

def top_files(request):
    """
    Топ самых больших файлов по размерам.

    :param request: HTTP-запрос.
    :return: Рендеринг страницы с топом файлов.
    """
    largest_files = File.objects.order_by('-size')[:10]
    context = {
        'largest_files': largest_files,
    }
    return render(request, 'top_files.html', context)

def top_images(request):
    """
    Топ самых больших изображений по произведению ширина x высота.

    :param request: HTTP-запрос.
    :return: Рендеринг страницы с топом изображений.
    """
    images = Image.objects.order_by('-area')[:10]
    context = {
        'images': images,
    }
    return render(request, 'top_images.html', context)

def top_documents(request):
    """
    Топ документов по количеству страниц.

    :param request: HTTP-запрос.
    :return: Рендеринг страницы с топом документов.
    """
    documents = Document.objects.order_by('-pages')[:10]
    context = {
        'documents': documents,
    }
    return render(request, 'top_documents.html', context)

def scan_directory(directory):
    """
    Функция сканирования директории.

    :param directory: Директория для сканирования.
    """
    for root, dirs, files in os.walk(directory):
        for file in files:
            full_path = os.path.join(root, file)
            file_size = os.stat(full_path).st_size
            mime_type = magic.from_file(full_path, mime=True)
            extension = os.path.splitext(file)[1][1:]
            
            try:
                if mime_type.startswith('image'):
                    output = subprocess.check_output(['identify', '-format', '%wx%h', full_path])
                    dimensions = output.decode('utf-8').strip().split('x')
                    width, height = int(dimensions[0]), int(dimensions[1])
                    image = Image(width=width, height=height)
                elif mime_type.startswith('application/pdf'):
                    output = subprocess.check_output(['pdfinfo', full_path])
                    pages = int(output.decode('utf-8').split('\n')[6].split(':')[1].strip())
                    document = Document(pages=pages)
                else:
                    continue
                
                new_file = File(path=full_path, size=file_size, extension=extension)
                new_file.save()
                if hasattr(new_file, 'image'):
                    image.file = new_file
                    image.save()
                elif hasattr(new_file, 'document'):
                    document.file = new_file
                    document.save()
            except Exception as e:
                print(f"Error processing {full_path}: {e}")

