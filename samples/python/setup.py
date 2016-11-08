from setuptools import setup


def readme():
    with open('README.md') as f:
        return f.read()


setup(name='pbapi',
      version='0.1',
      description='Command line utilities for the Google Proximity Beacon API',
      long_description=readme(),
      url='http://github.com/google/beacon-platform',
      author='Andrew Fitz Gibbon',
      author_email='afitzgibbon@google.com',
      license='Apache Software License',
      packages=['pbapi'],
      install_requires=[
        'google-api-python-client>=1.5.4',
        'httplib2>=0.9.2',
        'oauth2client>=2.0.1',
        'simplejson>=3.8.2',
        'six>=1.10.0'
      ],
      entry_points={
          'console_scripts': ['pb-cli=pbapi.command_line:main'],
      },
      include_package_data=True,
      zip_safe=False)
